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

@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    private let client = SupabaseClient(supabaseURL: SyncConfig.url, supabaseKey: SyncConfig.anonKey)
    private(set) var currentUser: User?

    var displayName: String {
        guard let user = currentUser else { return "" }
        if case let .string(name) = user.userMetadata["name"] { return name }
        return ""
    }

    func restoreSession() async {
        currentUser = try? await client.auth.session.user
    }

    func signUp(name: String, email: String, password: String) async throws {
        _ = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["name": .string(name)]
        )
        currentUser = try await client.auth.session.user
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

    func pushBudget(userId: UUID, payload: CloudBudgetPayload) async throws {
        try await assertSessionOwns(userId)
        struct UpsertRow: Encodable {
            var user_id: UUID
            var state: BudgetState
            var updated_at: Int64
            var name: String
        }
        let safeState = sanitizeState(payload.state)
        guard !safeState.categories.isEmpty else {
            throw NSError(domain: "BudgetStudio", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid budget payload."])
        }
        let row = UpsertRow(
            user_id: userId,
            state: safeState,
            updated_at: payload.updatedAt,
            name: String(payload.name.prefix(80))
        )
        // Explicit conflict target matches web upsert on primary key user_id.
        try await client
            .from("budgets")
            .upsert(row, onConflict: "user_id")
            .execute()
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
            return BudgetTransaction(
                id: String(tx.id.prefix(80)),
                date: date,
                type: tx.type,
                category: category,
                description: description.isEmpty ? category : description,
                account: String(tx.account.prefix(40)),
                amount: (tx.amount * 100).rounded() / 100
            )
        }
        return BudgetState(
            categories: categories,
            transactions: transactions,
            setupComplete: state.setupComplete,
            setupProfile: state.setupProfile
        )
    }

    func friendlyAuthError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
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
