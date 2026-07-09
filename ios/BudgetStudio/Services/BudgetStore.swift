import Foundation
import SwiftUI

@MainActor
final class BudgetStore: ObservableObject {
    @Published var state: BudgetState = BudgetDefaults.emptyState()
    @Published var selectedMonth: Date = Date()
    @Published var isAuthenticated = false
    @Published var isUnlocked = false
    @Published var userName = ""
    @Published var authError: String?
    @Published var isLoading = false
    @Published var toastMessage: String?
    @Published var faceIDEnabled: Bool {
        didSet { UserDefaults.standard.set(faceIDEnabled, forKey: "budget-studio-face-id") }
    }

    private let supabase = SupabaseService.shared
    private var cloudSaveTask: Task<Void, Never>?
    private var localUpdatedAt: Int64 = 0

    var monthKey: String { BudgetCalculator.monthKey(from: selectedMonth) }
    var monthSummary: MonthSummary { BudgetCalculator.monthSummary(state: state, month: monthKey) }
    var payPeriodSummary: PayPeriodSummary? { BudgetCalculator.payPeriodSummary(state: state, month: monthKey) }
    var categorySpending: [(category: BudgetCategory, spent: Double)] {
        BudgetCalculator.categorySpending(state: state, month: monthKey)
    }

    var canUseFaceID: Bool {
        faceIDEnabled && BiometricAuth.isAvailable && KeychainStore.load() != nil
    }

    var biometryLabel: String { BiometricAuth.biometryLabel }

    init() {
        faceIDEnabled = UserDefaults.standard.bool(forKey: "budget-studio-face-id")
    }

    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        await supabase.restoreSession()
        if let user = supabase.currentUser {
            isAuthenticated = true
            userName = supabase.displayName
            await loadFromCloud(userId: user.id)
            if canUseFaceID {
                isUnlocked = false
                await unlockWithFaceID()
            } else {
                isUnlocked = true
            }
        } else if canUseFaceID {
            // No live session, but Face ID can sign back in with saved credentials.
            isUnlocked = false
        }
    }

    func signUp(name: String, email: String, password: String) async {
        authError = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await supabase.signUp(name: name, email: email, password: password)
            isAuthenticated = true
            isUnlocked = true
            userName = name
            state = BudgetDefaults.emptyState()
            saveLocal()
            await pushCloud()
            offerFaceID(email: email, password: password)
        } catch {
            authError = supabase.friendlyAuthError(error)
        }
    }

    func signIn(email: String, password: String) async {
        authError = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await supabase.signIn(email: email, password: password)
            isAuthenticated = true
            isUnlocked = true
            userName = supabase.displayName
            await loadFromCloud(userId: supabase.currentUser!.id)
            offerFaceID(email: email, password: password)
        } catch {
            authError = supabase.friendlyAuthError(error)
        }
    }

    func unlockWithFaceID() async {
        authError = nil
        guard BiometricAuth.isAvailable else {
            authError = "\(biometryLabel) is not available on this device."
            return
        }
        let ok = await BiometricAuth.authenticate(reason: "Unlock Budget Studio")
        guard ok else {
            authError = "\(biometryLabel) was cancelled. Sign in with your password."
            return
        }

        if isAuthenticated {
            isUnlocked = true
            return
        }

        guard let credentials = KeychainStore.load() else {
            authError = "No saved login found. Sign in with your password once."
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            try await supabase.signIn(email: credentials.email, password: credentials.password)
            isAuthenticated = true
            isUnlocked = true
            userName = supabase.displayName
            await loadFromCloud(userId: supabase.currentUser!.id)
        } catch {
            KeychainStore.clear()
            faceIDEnabled = false
            authError = "Saved login expired. Sign in with your password again."
        }
    }

    func enableFaceID(email: String, password: String) {
        guard BiometricAuth.isAvailable else {
            showToast("\(biometryLabel) is not available on this device.")
            return
        }
        KeychainStore.save(.init(email: email, password: password))
        faceIDEnabled = true
        showToast("\(biometryLabel) enabled.")
    }

    func disableFaceID() {
        faceIDEnabled = false
        KeychainStore.clear()
        showToast("\(biometryLabel) turned off.")
    }

    private func offerFaceID(email: String, password: String) {
        guard BiometricAuth.isAvailable else { return }
        // Quietly save credentials the first time Face ID is available so the unlock button works.
        // User can turn it off in Settings.
        if !faceIDEnabled {
            KeychainStore.save(.init(email: email, password: password))
            faceIDEnabled = true
            showToast("\(biometryLabel) ready for next time.")
        } else {
            KeychainStore.save(.init(email: email, password: password))
        }
    }

    func resetPassword(email: String) async {
        authError = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await supabase.resetPassword(email: email)
            showToast("Check your email for a reset link.")
        } catch {
            authError = supabase.friendlyAuthError(error)
        }
    }

    func signOut() async {
        try? await supabase.signOut()
        isAuthenticated = false
        isUnlocked = false
        userName = ""
        state = BudgetDefaults.emptyState()
        // Keep Face ID credentials so the next launch can unlock quickly.
    }

    func loadDemo() {
        state = BudgetDefaults.demoState()
        saveLocal()
        scheduleCloudSave()
        showToast("Demo budget loaded.")
    }

    func addTransaction(_ transaction: BudgetTransaction) {
        state.transactions.insert(transaction, at: 0)
        saveLocal()
        scheduleCloudSave()
        showToast("Transaction added.")
    }

    func updateTransaction(_ transaction: BudgetTransaction) {
        guard let index = state.transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        state.transactions[index] = transaction
        saveLocal()
        scheduleCloudSave()
        showToast("Transaction updated.")
    }

    func deleteTransaction(id: String) {
        state.transactions.removeAll { $0.id == id }
        saveLocal()
        scheduleCloudSave()
        showToast("Transaction deleted.")
    }

    func updateCategoryBudget(name: String, budget: Double) {
        guard let index = state.categories.firstIndex(where: { $0.name == name }) else { return }
        state.categories[index].budget = max(0, budget)
        saveLocal()
        scheduleCloudSave()
    }

    func addCategory(name: String, group: String, budget: Double) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !state.categories.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        state.categories.append(BudgetCategory(name: trimmed, type: "Expense", group: group, budget: budget))
        saveLocal()
        scheduleCloudSave()
    }

    func completeSetup(with profile: SetupProfile, categories: [BudgetCategory]) {
        state.categories = categories
        state.setupComplete = true
        state.setupProfile = profile
        saveLocal()
        scheduleCloudSave()
        showToast("Budget setup complete.")
    }

    private func cacheKey(for userId: UUID) -> String {
        "budget-studio-state-v7:uid:\(userId.uuidString)"
    }

    private func saveLocal() {
        localUpdatedAt = Int64(Date().timeIntervalSince1970 * 1000)
        guard let userId = supabase.currentUser?.id,
              let data = try? JSONEncoder().encode(CloudBudgetPayload(state: state, updatedAt: localUpdatedAt, name: userName)) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(for: userId))
    }

    private func loadLocal(userId: UUID) -> CloudBudgetPayload? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: userId)),
              let payload = try? JSONDecoder().decode(CloudBudgetPayload.self, from: data) else { return nil }
        return payload
    }

    private func loadFromCloud(userId: UUID) async {
        do {
            let cloud = try await supabase.fetchBudget(userId: userId)
            let local = loadLocal(userId: userId)
            if let cloud, (local == nil || cloud.updatedAt >= (local?.updatedAt ?? 0)) {
                state = cloud.state
                localUpdatedAt = cloud.updatedAt
                saveLocal()
            } else if cloud == nil, let local {
                state = local.state
                localUpdatedAt = local.updatedAt
                await pushCloud()
            } else if cloud == nil {
                state = BudgetDefaults.emptyState()
            }
        } catch {
            if let local = loadLocal(userId: userId) {
                state = local.state
                localUpdatedAt = local.updatedAt
            }
            showToast("Working offline — changes will sync when you're back online.")
        }
    }

    private func pushCloud() async {
        guard let userId = supabase.currentUser?.id else { return }
        let payload = CloudBudgetPayload(state: state, updatedAt: localUpdatedAt, name: userName)
        do {
            try await supabase.pushBudget(userId: userId, payload: payload)
        } catch {
            showToast("Could not sync yet. We'll retry when you're online.")
        }
    }

    private func scheduleCloudSave() {
        cloudSaveTask?.cancel()
        cloudSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            await pushCloud()
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
    }
}
