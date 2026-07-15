import Foundation
import Supabase

enum SyncConfig {
    // Anon / publishable key only — never embed service_role in the app.
    static let url = URL(string: "https://dhlaqqghjfmgdlkfxlxg.supabase.co")!
    static let anonKey = "sb_publishable_poVoneGFjZxQ2ecE7fQSiA_7YJinWt6"
}

struct CloudBudgetPayload: Codable {
    var state: BudgetState
    var updatedAt: Int64
    var name: String
}

struct CloudBudgetRow: Codable {
    var state: BudgetState
    var updated_at: Int64
    var name: String
}

struct SharedMembership: Equatable {
    var id: UUID
    var role: String
}

struct BudgetMemberRow: Codable, Equatable {
    var user_id: UUID
    var role: String
    var joined_at: String?
}

@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    private let client = SupabaseClient(supabaseURL: SyncConfig.url, supabaseKey: SyncConfig.anonKey)
    private(set) var currentUser: User?
    private var sharedChannel: RealtimeChannelV2?
    private var sharedListenTask: Task<Void, Never>?

    var displayName: String {
        guard let user = currentUser else { return "" }
        if case let .string(name) = user.userMetadata["name"] { return name }
        return ""
    }

    func restoreSession() async {
        currentUser = try? await client.auth.session.user
    }

    enum SignUpOutcome {
        case signedIn
        case confirmationRequired
        case existingAccount
    }

    /// Confirm links open the web app; any device can finish the confirmation.
    private static let emailRedirectURL = URL(string: "https://elcomparob111.github.io/budget-studio/")

    func signUp(name: String, email: String, password: String) async throws -> SignUpOutcome {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["name": .string(name)],
            redirectTo: Self.emailRedirectURL
        )
        // Supabase obfuscates duplicate signups: the returned user has no identities.
        if (response.user.identities ?? []).isEmpty {
            return .existingAccount
        }
        guard let session = response.session else {
            // Confirm-email is on: no session until the link is clicked.
            return .confirmationRequired
        }
        currentUser = session.user
        return .signedIn
    }

    func resendConfirmationEmail(email: String) async throws {
        try await client.auth.resend(
            email: email,
            type: .signup,
            emailRedirectTo: Self.emailRedirectURL
        )
    }

    func isEmailNotConfirmed(_ error: Error) -> Bool {
        error.localizedDescription.lowercased().contains("not confirmed")
    }

    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
        currentUser = try await client.auth.session.user
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
    }

    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    func fetchBudget(userId: UUID) async throws -> CloudBudgetPayload? {
        try await assertSessionOwns(userId)
        let rows: [CloudBudgetRow] = try await client
            .from("budgets")
            .select("state, updated_at, name")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { return nil }
        return CloudBudgetPayload(
            state: sanitizeState(row.state),
            updatedAt: row.updated_at,
            name: String(row.name.prefix(80))
        )
    }

    func pushBudget(userId: UUID, payload: CloudBudgetPayload) async throws -> Int64 {
        try await assertSessionOwns(userId)
        struct UpsertRow: Encodable {
            var user_id: UUID
            var state: BudgetState
            var name: String
        }
        struct UpdatedRow: Decodable {
            var updated_at: Int64
        }
        let safeState = sanitizeState(payload.state)
        guard !safeState.categories.isEmpty else {
            throw NSError(domain: "BudgetStudio", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid budget payload."])
        }
        let row = UpsertRow(
            user_id: userId,
            state: safeState,
            name: String(payload.name.prefix(80))
        )
        // updated_at is set by DB trigger (security-hardening.sql) — ignore client clock.
        let rows: [UpdatedRow] = try await client
            .from("budgets")
            .upsert(row, onConflict: "user_id")
            .select("updated_at")
            .execute()
            .value
        return rows.first?.updated_at ?? payload.updatedAt
    }

    /// Refuse cloud access unless the live session matches the requested user id.
    private func assertSessionOwns(_ userId: UUID) async throws {
        let sessionUser = try await client.auth.session.user
        guard sessionUser.id == userId else {
            throw NSError(
                domain: "BudgetStudio",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "You can only access your own budget."]
            )
        }
        currentUser = sessionUser
    }

    private static let maxCategories = 200
    private static let maxTransactions = 20_000

    private func sanitizeState(_ state: BudgetState) -> BudgetState {
        var categories = Array(state.categories.prefix(Self.maxCategories)).compactMap { cat -> BudgetCategory? in
            let name = String(cat.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: ">", with: "")
            guard !name.isEmpty else { return nil }
            let type = (cat.type == "Income" || cat.type == "Expense") ? cat.type : "Expense"
            let group = String(cat.group.prefix(40))
            let budget = min(max(cat.budget, 0), 1_000_000_000)
            return BudgetCategory(name: name, type: type, group: group.isEmpty ? "Needs" : group, budget: budget)
        }
        if categories.isEmpty {
            categories = BudgetDefaults.emptyState().categories
        }
        let transactions = Array(state.transactions.prefix(Self.maxTransactions)).compactMap { tx -> BudgetTransaction? in
            guard tx.type == "Income" || tx.type == "Expense" else { return nil }
            guard tx.amount > 0, tx.amount <= 1_000_000_000 else { return nil }
            let date = tx.date
            guard date.count == 10 else { return nil }
            let category = String(tx.category.prefix(40))
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: ">", with: "")
            guard !category.isEmpty else { return nil }
            let description = String(tx.description.prefix(120))
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: ">", with: "")
            let safeIdChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
            let rawId = String(tx.id.unicodeScalars.filter { safeIdChars.contains($0) }.prefix(80).map(Character.init))
            let addedByRaw = tx.addedBy.map {
                String($0.unicodeScalars.filter { safeIdChars.contains($0) }.prefix(80).map(Character.init))
            }
            let addedByName = tx.addedByName.map {
                String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                    .replacingOccurrences(of: "<", with: "")
                    .replacingOccurrences(of: ">", with: "")
            }
            return BudgetTransaction(
                id: rawId.isEmpty ? String(UUID().uuidString.prefix(80)) : rawId,
                date: date,
                type: tx.type,
                category: category,
                description: description.isEmpty ? category : description,
                account: String(tx.account.prefix(40)),
                amount: (tx.amount * 100).rounded() / 100,
                addedBy: (addedByRaw?.isEmpty == false) ? addedByRaw : nil,
                addedByName: (addedByName?.isEmpty == false) ? addedByName : nil
            )
        }
        let recurring = Array((state.recurring ?? []).prefix(500)).compactMap { item -> RecurringItem? in
            guard item.type == "Income" || item.type == "Expense" else { return nil }
            guard item.amount > 0, item.amount <= 1_000_000_000 else { return nil }
            let category = String(item.category.prefix(40))
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: ">", with: "")
            guard !category.isEmpty else { return nil }
            return RecurringItem(
                id: String(item.id.prefix(80)),
                type: item.type,
                category: category,
                description: String(item.description.prefix(120))
                    .replacingOccurrences(of: "<", with: "")
                    .replacingOccurrences(of: ">", with: ""),
                account: String(item.account.prefix(40)),
                amount: (item.amount * 100).rounded() / 100,
                dayOfMonth: min(31, max(1, item.dayOfMonth)),
                lastPostedMonth: String(item.lastPostedMonth.prefix(7))
            )
        }
        let savingsGoals = Array((state.savingsGoals ?? []).prefix(50)).compactMap { goal -> SavingsGoal? in
            let name = String(goal.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: ">", with: "")
            guard !name.isEmpty else { return nil }
            let safeIdChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
            let rawId = String(goal.id.unicodeScalars.filter { safeIdChars.contains($0) }.prefix(80).map(Character.init))
            var target = goal.target
            if !target.isFinite || target <= 0 { target = 1 }
            target = min(max(target, 0), 1_000_000_000)
            var current = goal.current
            if !current.isFinite || current < 0 { current = 0 }
            current = min(current, 1_000_000_000)
            return SavingsGoal(
                id: rawId.isEmpty ? String(UUID().uuidString.prefix(80)) : rawId,
                name: name,
                target: (target * 100).rounded() / 100,
                current: (current * 100).rounded() / 100
            )
        }
        return BudgetState(
            categories: categories,
            transactions: transactions,
            recurring: recurring.isEmpty ? state.recurring : recurring,
            savingsGoals: savingsGoals.isEmpty ? state.savingsGoals : savingsGoals,
            setupComplete: state.setupComplete,
            setupProfile: state.setupProfile
        )
    }

    // MARK: - Shared/couples budgets (mirrors sync.js)

    private func requireSessionUid() async throws -> UUID {
        let sessionUser = try await client.auth.session.user
        currentUser = sessionUser
        return sessionUser.id
    }

    func fetchMySharedMembership() async throws -> SharedMembership? {
        let uid = try await requireSessionUid()
        struct Row: Decodable {
            var budget_id: UUID
            var role: String
        }
        let rows: [Row] = try await client
            .from("budget_members")
            .select("budget_id, role")
            .eq("user_id", value: uid.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { return nil }
        return SharedMembership(id: row.budget_id, role: row.role)
    }

    func fetchSharedBudget(budgetId: UUID) async throws -> CloudBudgetPayload? {
        _ = try await requireSessionUid()
        let rows: [CloudBudgetRow] = try await client
            .from("shared_budgets")
            .select("state, updated_at, name")
            .eq("id", value: budgetId.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { return nil }
        return CloudBudgetPayload(
            state: sanitizeState(row.state),
            updatedAt: row.updated_at,
            name: String(row.name.prefix(80))
        )
    }

    func pushSharedBudget(budgetId: UUID, payload: CloudBudgetPayload) async throws -> Int64 {
        _ = try await requireSessionUid()
        struct UpdateRow: Encodable {
            var state: BudgetState
        }
        struct UpdatedRow: Decodable {
            var updated_at: Int64
        }
        let safeState = sanitizeState(payload.state)
        guard !safeState.categories.isEmpty else {
            throw NSError(domain: "BudgetStudio", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid budget payload."])
        }
        // Deliberately not updating `name` — same as web. updated_at is DB-triggered.
        let rows: [UpdatedRow] = try await client
            .from("shared_budgets")
            .update(UpdateRow(state: safeState))
            .eq("id", value: budgetId.uuidString)
            .select("updated_at")
            .execute()
            .value
        return rows.first?.updated_at ?? payload.updatedAt
    }

    func createSharedBudget(state: BudgetState, name: String) async throws -> UUID {
        _ = try await requireSessionUid()
        struct Params: Encodable {
            var initial_state: BudgetState
            var budget_name: String
        }
        let params = Params(
            initial_state: sanitizeState(state),
            budget_name: String(name.prefix(80))
        )
        let id: UUID = try await client
            .rpc("create_shared_budget", params: params)
            .execute()
            .value
        return id
    }

    func createBudgetInvite(budgetId: UUID) async throws -> UUID {
        let uid = try await requireSessionUid()
        struct InsertRow: Encodable {
            var budget_id: UUID
            var created_by: UUID
        }
        struct TokenRow: Decodable {
            var token: UUID
        }
        let rows: [TokenRow] = try await client
            .from("budget_invites")
            .insert(InsertRow(budget_id: budgetId, created_by: uid))
            .select("token")
            .execute()
            .value
        guard let token = rows.first?.token else {
            throw NSError(domain: "BudgetStudio", code: 500, userInfo: [NSLocalizedDescriptionKey: "Couldn't create an invite link."])
        }
        return token
    }

    func acceptBudgetInvite(token: UUID) async throws -> UUID {
        _ = try await requireSessionUid()
        struct Params: Encodable {
            var invite_token: UUID
        }
        let budgetId: UUID = try await client
            .rpc("accept_budget_invite", params: Params(invite_token: token))
            .execute()
            .value
        return budgetId
    }

    func listBudgetMembers(budgetId: UUID) async throws -> [BudgetMemberRow] {
        _ = try await requireSessionUid()
        let rows: [BudgetMemberRow] = try await client
            .from("budget_members")
            .select("user_id, role, joined_at")
            .eq("budget_id", value: budgetId.uuidString)
            .order("joined_at", ascending: true)
            .execute()
            .value
        return rows
    }

    func leaveSharedBudget(budgetId: UUID) async throws {
        let uid = try await requireSessionUid()
        try await client
            .from("budget_members")
            .delete()
            .eq("budget_id", value: budgetId.uuidString)
            .eq("user_id", value: uid.uuidString)
            .execute()
    }

    /// Realtime: notify on shared_budgets UPDATE. Callback should refetch.
    func subscribeSharedBudget(budgetId: UUID, onRemoteChange: @escaping @Sendable () -> Void) async {
        await unsubscribeSharedBudget()
        let channel = client.channel("shared-budget-\(budgetId.uuidString.lowercased())")
        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "shared_budgets",
            filter: .eq("id", value: budgetId.uuidString.lowercased())
        )
        do {
            try await channel.subscribeWithError()
        } catch {
            return
        }
        sharedChannel = channel
        sharedListenTask = Task {
            for await _ in updates {
                onRemoteChange()
            }
        }
    }

    func unsubscribeSharedBudget() async {
        sharedListenTask?.cancel()
        sharedListenTask = nil
        if let channel = sharedChannel {
            await client.removeChannel(channel)
            sharedChannel = nil
        }
    }

    static let webJoinBaseURL = "https://elcomparob111.github.io/budget-studio/"

    static func inviteURL(token: UUID) -> String {
        "\(webJoinBaseURL)?join=\(token.uuidString.lowercased())"
    }

    /// Parse a join token from a URL, raw UUID, or pasted invite link.
    static func parseJoinToken(from raw: String) -> UUID? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let uuid = UUID(uuidString: trimmed) { return uuid }
        guard let url = URL(string: trimmed) else { return nil }
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let join = comps.queryItems?.first(where: { $0.name == "join" })?.value,
           let uuid = UUID(uuidString: join) {
            return uuid
        }
        // budgetstudio://join/<uuid>
        if url.scheme?.lowercased() == "budgetstudio",
           url.host?.lowercased() == "join",
           let uuid = UUID(uuidString: url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) {
            return uuid
        }
        if url.scheme?.lowercased() == "budgetstudio",
           url.pathComponents.count >= 2,
           url.pathComponents[1].lowercased() == "join" || url.host == nil,
           let last = url.pathComponents.last,
           let uuid = UUID(uuidString: last) {
            return uuid
        }
        return nil
    }

    func friendlySharedError(_ error: Error) -> String {
        let raw = error.localizedDescription
        let lower = raw.lowercased()
        if lower.contains("expired") { return "That invite link expired — ask for a new one." }
        if lower.contains("already used") { return "That invite link was already used." }
        if lower.contains("not found") || lower.contains("invalid") {
            return "That invite didn't work — ask for a fresh link."
        }
        return friendlyAuthError(error)
    }

    func friendlyAuthError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("not confirmed") {
            return "Your email isn't confirmed yet. Check your inbox for the link, or resend it."
        }
        if message.contains("rate limit") || message.contains("too many") {
            return "Too many attempts. Wait a minute and try again."
        }
        if message.contains("valid email") || message.contains("invalid format") {
            return "Enter a valid email address."
        }
        if message.contains("at least") && message.contains("character") {
            return "Password does not meet the requirements."
        }
        if message.contains("invalid login")
            || message.contains("invalid credentials")
            || message.contains("already registered")
            || message.contains("user not found") {
            return "Unable to sign in with those details. Check your email and password, or create an account."
        }
        return "Something went wrong. Please try again."
    }
}
