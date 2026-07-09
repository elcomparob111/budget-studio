import Foundation
import Supabase

enum SyncConfig {
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
        let rows: [CloudBudgetRow] = try await client
            .from("budgets")
            .select("state, updated_at, name")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { return nil }
        return CloudBudgetPayload(state: row.state, updatedAt: row.updated_at, name: row.name)
    }

    func pushBudget(userId: UUID, payload: CloudBudgetPayload) async throws {
        struct UpsertRow: Encodable {
            var user_id: UUID
            var state: BudgetState
            var updated_at: Int64
            var name: String
        }
        let row = UpsertRow(
            user_id: userId,
            state: payload.state,
            updated_at: payload.updatedAt,
            name: payload.name
        )
        try await client.from("budgets").upsert(row).execute()
    }

    func friendlyAuthError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("invalid login credentials") { return "Email or password is incorrect." }
        if message.contains("already registered") { return "That email already has an account. Try signing in." }
        if message.contains("valid email") { return "That doesn't look like a valid email." }
        if message.contains("at least 6") { return "Password needs at least 6 characters." }
        return "Something went wrong. Please try again."
    }
}
