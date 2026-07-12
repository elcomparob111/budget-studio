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
    /// Non-nil while waiting for the signup confirmation link to be clicked.
    @Published var pendingConfirmEmail: String?
    /// Memory only, never persisted; enables auto sign-in once confirmed.
    private var pendingConfirmPassword = ""
    @Published var toastMessage: String?
    @Published var faceIDEnabled: Bool {
        didSet { UserDefaults.standard.set(faceIDEnabled, forKey: "budget-studio-face-id") }
    }

    private let supabase = SupabaseService.shared
    private var cloudSaveTask: Task<Void, Never>?
    private var localUpdatedAt: Int64 = 0
    /// Pending cloud push after a failed sync — retried quietly on next save/bootstrap.
    private var cloudDirty = false
    /// Avoid toast spam while typing category budgets or during rapid edits.
    private var didNotifySyncFailure = false

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
            switch try await supabase.signUp(name: name, email: email, password: password) {
            case .existingAccount:
                authError = "That email is already registered. Sign in, or use Forgot password."
            case .confirmationRequired:
                pendingConfirmEmail = email
                pendingConfirmPassword = password
            case .signedIn:
                isAuthenticated = true
                isUnlocked = true
                userName = name
                state = BudgetDefaults.emptyState()
                saveLocal()
                await pushCloud()
                offerFaceID(email: email, password: password)
            }
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
            pendingConfirmEmail = nil
            pendingConfirmPassword = ""
            userName = supabase.displayName
            // Load cloud before unlocking so MainTabView does not flash setup
            // against the empty default state (setupComplete: false).
            await loadFromCloud(userId: supabase.currentUser!.id)
            isAuthenticated = true
            isUnlocked = true
            offerFaceID(email: email, password: password)
        } catch {
            if supabase.isEmailNotConfirmed(error) {
                pendingConfirmEmail = email
                pendingConfirmPassword = password
            } else {
                authError = supabase.friendlyAuthError(error)
            }
        }
    }

    /// Retry sign-in from the check-your-email screen. Succeeds once the
    /// confirmation link has been clicked on any device.
    func retryConfirmedSignIn(silent: Bool = false) async {
        guard let email = pendingConfirmEmail else { return }
        guard !pendingConfirmPassword.isEmpty else {
            if !silent {
                cancelPendingConfirmation()
                authError = "Enter your password to sign in."
            }
            return
        }
        await signIn(email: email, password: pendingConfirmPassword)
        if silent, !isAuthenticated {
            authError = nil
        } else if !silent, pendingConfirmEmail != nil {
            authError = "Not confirmed yet — the link may take a minute to register. Try again shortly."
        }
    }

    func resendConfirmation() async {
        guard let email = pendingConfirmEmail else { return }
        authError = nil
        do {
            try await supabase.resendConfirmationEmail(email: email)
        } catch {
            authError = supabase.friendlyAuthError(error)
        }
    }

    func cancelPendingConfirmation() {
        pendingConfirmEmail = nil
        pendingConfirmPassword = ""
        authError = nil
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
            userName = supabase.displayName
            await loadFromCloud(userId: supabase.currentUser!.id)
            isAuthenticated = true
            isUnlocked = true
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
        let previousUserId = supabase.currentUser?.id
        try? await supabase.signOut()
        clearLocalCaches(for: previousUserId)
        isAuthenticated = false
        isUnlocked = false
        userName = ""
        state = BudgetDefaults.emptyState()
        cloudDirty = false
        // Keep Face ID credentials so the next launch can unlock quickly.
    }

    /// Remove cached budget blobs for this user (and any leftover uid-keyed caches).
    private func clearLocalCaches(for userId: UUID?) {
        let defaults = UserDefaults.standard
        if let userId {
            defaults.removeObject(forKey: cacheKey(for: userId))
        }
        // Sweep any other budget-studio uid caches on a shared device.
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("budget-studio-state-v7:uid:") {
            defaults.removeObject(forKey: key)
        }
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
        // Remove paycheck rows invented by the old web wizard (e.g. "Biweekly paycheck").
        state.transactions = Self.stripAutoGeneratedPaychecks(state.transactions)
        saveLocal()
        scheduleCloudSave()
        showToast("Budget setup complete.")
    }

    /// Update pay schedule after setup — recalculates Overview pay window on next render.
    func updatePaySchedule(payAmount: Double, payFrequency: String, nextPayDate: String) {
        var profile = state.setupProfile ?? SetupProfile(
            presetId: "single",
            income: 0,
            payAmount: 0,
            payFrequency: "biweekly",
            nextPayDate: BudgetCalculator.todayString(),
            completedAt: ISO8601DateFormatter().string(from: Date()),
            demo: false
        )
        let amount = max(0, payAmount)
        profile.payAmount = amount
        profile.payFrequency = payFrequency
        profile.nextPayDate = nextPayDate
        profile.income = Self.monthlyIncomeFromPay(amount, payFrequency)
        profile.demo = false
        state.setupProfile = profile
        state.setupComplete = true
        saveLocal()
        scheduleCloudSave()
        showToast("Pay schedule updated.")
    }

    private static func monthlyIncomeFromPay(_ amount: Double, _ frequency: String) -> Double {
        switch frequency {
        case "weekly": return (amount * 52 / 12).rounded()
        case "biweekly": return (amount * 26 / 12).rounded()
        case "semimonthly": return (amount * 2).rounded()
        default: return amount.rounded()
        }
    }

    /// Persist setup as done without changing categories (Close / Skip).
    /// Matches web `closeWizard` which finishes setup instead of leaving it incomplete.
    func markSetupCompleteIfNeeded() {
        guard !state.setupComplete else { return }
        state.setupComplete = true
        if state.setupProfile == nil {
            let day = DateFormatter()
            day.calendar = Calendar(identifier: .gregorian)
            day.locale = Locale(identifier: "en_US_POSIX")
            day.dateFormat = "yyyy-MM-dd"
            state.setupProfile = SetupProfile(
                presetId: "single",
                income: 0,
                payAmount: 0,
                payFrequency: "biweekly",
                nextPayDate: day.string(from: Date()),
                completedAt: ISO8601DateFormatter().string(from: Date()),
                demo: false
            )
        }
        saveLocal()
        scheduleCloudSave()
    }

    /// Matches income rows invented by the old web setup wizard.
    static func isAutoGeneratedPaycheck(_ tx: BudgetTransaction) -> Bool {
        guard tx.type == "Income", tx.category == "Salary", tx.account == "Checking" else { return false }
        let labels = ["Weekly paycheck", "Biweekly paycheck", "Twice a month paycheck", "Monthly paycheck", "Paycheck paycheck"]
        return labels.contains(tx.description)
    }

    static func stripAutoGeneratedPaychecks(_ transactions: [BudgetTransaction]) -> [BudgetTransaction] {
        transactions.filter { !isAutoGeneratedPaycheck($0) }
    }

    private func applyLoadedState(_ loaded: BudgetState, updatedAt: Int64, persistCleanup: Bool) {
        var cleaned = loaded
        let before = cleaned.transactions.count
        cleaned.transactions = Self.stripAutoGeneratedPaychecks(cleaned.transactions)
        let stripped = cleaned.transactions.count != before
        state = cleaned
        localUpdatedAt = stripped ? Int64(Date().timeIntervalSince1970 * 1000) : updatedAt
        if persistCleanup {
            saveLocalKeepingTimestamp()
            if stripped {
                scheduleCloudSave()
            }
        }
    }

    private func saveLocalKeepingTimestamp() {
        guard let userId = supabase.currentUser?.id,
              let data = try? JSONEncoder().encode(CloudBudgetPayload(state: state, updatedAt: localUpdatedAt, name: userName)) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(for: userId))
    }

    private func loadFromCloud(userId: UUID) async {
        do {
            let cloud = try await supabase.fetchBudget(userId: userId)
            let local = loadLocal(userId: userId)
            let cloudAt = cloud?.updatedAt ?? 0
            let localAt = local?.updatedAt ?? 0

            if let cloud, local == nil || cloudAt >= localAt {
                applyLoadedState(cloud.state, updatedAt: cloud.updatedAt, persistCleanup: true)
            } else if let local {
                // Prefer newer local (e.g. setup finished before cloud push landed).
                applyLoadedState(local.state, updatedAt: local.updatedAt, persistCleanup: true)
                if cloud == nil || localAt > cloudAt {
                    await pushCloud(notifyOnFailure: false)
                }
            } else {
                state = BudgetDefaults.emptyState()
            }
            // Quietly flush any edits that failed to sync earlier.
            if cloudDirty {
                await pushCloud(notifyOnFailure: false)
            }
        } catch {
            if let local = loadLocal(userId: userId) {
                applyLoadedState(local.state, updatedAt: local.updatedAt, persistCleanup: false)
            }
            cloudDirty = true
            // One soft notice on launch — never blocks local editing.
            if !didNotifySyncFailure {
                didNotifySyncFailure = true
                showToast("Working offline — changes save on this device.")
            }
        }
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

    private func pushCloud(notifyOnFailure: Bool = true) async {
        guard let userId = supabase.currentUser?.id else { return }
        let payload = CloudBudgetPayload(state: state, updatedAt: localUpdatedAt, name: userName)
        do {
            try await supabase.pushBudget(userId: userId, payload: payload)
            cloudDirty = false
            didNotifySyncFailure = false
        } catch {
            cloudDirty = true
            // Local save already succeeded — never block input. Toast at most once until sync works again.
            if notifyOnFailure && !didNotifySyncFailure {
                didNotifySyncFailure = true
                showToast("Saved on this device. Cloud sync will retry shortly.")
            }
        }
    }

    private func scheduleCloudSave() {
        cloudSaveTask?.cancel()
        cloudSaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(900))
            } catch {
                // Cancelled by a newer edit — do not push (old bug: try? let cancelled tasks still sync).
                return
            }
            guard !Task.isCancelled else { return }
            await self?.pushCloud()
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
    }
}
