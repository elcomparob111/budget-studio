import Foundation
import SwiftUI
import WidgetKit

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
    @Published var billRemindersEnabled: Bool {
        didSet {
            BillReminderService.shared.isEnabled = billRemindersEnabled
            Task { await refreshBillReminders() }
        }
    }

    /// Active shared-budget membership, or nil when using the personal budget.
    @Published var sharedMembership: SharedMembership?
    @Published var inviteLink: String?
    @Published var sharedStatusMessage: String?
    @Published var sharedMemberCount: Int?
    @Published var isSharedBusy = false
    /// True when a join token is stashed (survives sign-in).
    @Published var hasPendingJoinInvite = false
    /// Set by `budgetstudio://add` — MainTabView opens the add sheet.
    @Published var pendingQuickAdd = false

    private let supabase = SupabaseService.shared
    private var cloudSaveTask: Task<Void, Never>?
    private var localUpdatedAt: Int64 = 0
    /// Pending cloud push after a failed sync — retried quietly on next save/bootstrap.
    private var cloudDirty = false
    /// Avoid toast spam while typing category budgets or during rapid edits.
    private var didNotifySyncFailure = false
    /// Last shared remote `updated_at` we applied (skip own write echoes).
    private var lastSharedAppliedAt: Int64 = 0

    private static let pendingJoinKey = "budget-studio-pending-join"

    var isInSharedBudget: Bool { sharedMembership != nil }
    var isSharedOwner: Bool { sharedMembership?.role == "owner" }

    var monthKey: String { BudgetCalculator.monthKey(from: selectedMonth) }
    var monthSummary: MonthSummary { BudgetCalculator.monthSummary(state: state, month: monthKey) }
    var payPeriodSummary: PayPeriodSummary? { BudgetCalculator.payPeriodSummary(state: state, month: monthKey) }
    var payPeriodPreviews: [PayPeriodPreview] { BudgetCalculator.payPeriodPreviews(state: state, month: monthKey) }
    var nextPayPeriodHint: String? { BudgetCalculator.nextPayPeriodHint(state: state, month: monthKey) }
    var categorySpending: [(category: BudgetCategory, spent: Double)] {
        BudgetCalculator.categorySpending(state: state, month: monthKey)
    }

    var canUseFaceID: Bool {
        faceIDEnabled && BiometricAuth.isAvailable && KeychainStore.load() != nil
    }

    var biometryLabel: String { BiometricAuth.biometryLabel }

    init() {
        faceIDEnabled = UserDefaults.standard.bool(forKey: "budget-studio-face-id")
        billRemindersEnabled = BillReminderService.shared.isEnabled
        hasPendingJoinInvite = UserDefaults.standard.string(forKey: Self.pendingJoinKey) != nil
        BillReminderService.shared.install()
    }

    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        await supabase.restoreSession()
        if let user = supabase.currentUser {
            isAuthenticated = true
            userName = supabase.displayName
            await resolveSharedAndLoad(userId: user.id)
            await refreshBillReminders()
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

    /// Turn bill reminders on (requests permission) or off.
    func setBillRemindersEnabled(_ enabled: Bool) async {
        if enabled {
            let ok = await BillReminderService.shared.requestAuthorization()
            if !ok {
                billRemindersEnabled = false
                showToast("Notifications are off — enable them in Settings to get bill reminders.")
                return
            }
        }
        // Assigning triggers didSet → refresh.
        if billRemindersEnabled != enabled {
            billRemindersEnabled = enabled
        } else if enabled {
            await refreshBillReminders()
        }
        showToast(enabled ? "Bill reminders on — we'll nudge you the morning they're due." : "Bill reminders off.")
    }

    func refreshBillReminders() async {
        await BillReminderService.shared.refresh(items: state.recurringItems)
    }

    /// Stash a join token from a deep link or paste so it survives sign-in.
    func captureJoinToken(from raw: String) {
        guard let token = SupabaseService.parseJoinToken(from: raw) else {
            showToast("That doesn't look like an invite link.")
            return
        }
        UserDefaults.standard.set(token.uuidString.lowercased(), forKey: Self.pendingJoinKey)
        hasPendingJoinInvite = true
        if isAuthenticated, let userId = supabase.currentUser?.id {
            Task { await resolveSharedAndLoad(userId: userId) }
        } else {
            showToast("Sign in to join the shared budget.")
        }
    }

    func handleIncomingURL(_ url: URL) {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        if host == "add" || path == "/add" || path.hasSuffix("/add") {
            pendingQuickAdd = true
            return
        }
        captureJoinToken(from: url.absoluteString)
    }

    /// Push safe-to-spend into the App Group so the home-screen widget stays current.
    func publishWidgetSnapshot() {
        let month = BudgetDefaults.currentMonthKey()
        let summary = BudgetCalculator.monthSummary(state: state, month: month)
        let label: String = {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM"
            return formatter.string(from: Date())
        }()
        let snapshot = WidgetSnapshot(
            safeToSpend: summary.left,
            monthLabel: label,
            updatedAt: Date().timeIntervalSince1970,
            signedIn: isAuthenticated
        )
        snapshot.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "BudgetStudioWidget")
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
                await resolveSharedAndLoad(userId: supabase.currentUser!.id)
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
            await resolveSharedAndLoad(userId: supabase.currentUser!.id)
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
            await resolveSharedAndLoad(userId: supabase.currentUser!.id)
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
        await teardownShared()
        try? await supabase.signOut()
        clearLocalCaches(for: previousUserId)
        isAuthenticated = false
        isUnlocked = false
        userName = ""
        state = BudgetDefaults.emptyState()
        cloudDirty = false
        inviteLink = nil
        sharedStatusMessage = nil
        publishWidgetSnapshot()
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
        Task { await refreshBillReminders() }
    }

    func addTransaction(_ transaction: BudgetTransaction) {
        var stamped = transaction
        stampAuthorIfNeeded(&stamped)
        state.transactions.insert(stamped, at: 0)
        saveLocal()
        scheduleCloudSave()
        showToast("Transaction added.")
    }

    func updateTransaction(_ transaction: BudgetTransaction) {
        guard let index = state.transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        var updated = transaction
        // Keep original authorship on edits; don't re-stamp.
        updated.addedBy = state.transactions[index].addedBy
        updated.addedByName = state.transactions[index].addedByName
        state.transactions[index] = updated
        saveLocal()
        scheduleCloudSave()
        showToast("Transaction updated.")
    }

    /// Activity chip label for a shared-budget row; nil when untagged / personal.
    func authorLabel(for transaction: BudgetTransaction) -> String? {
        guard isInSharedBudget, let addedBy = transaction.addedBy else { return nil }
        if let uid = supabase.currentUser?.id.uuidString.lowercased(),
           addedBy.lowercased() == uid {
            return "You"
        }
        let name = transaction.addedByName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Partner" : name
    }

    private func stampAuthorIfNeeded(_ transaction: inout BudgetTransaction) {
        guard isInSharedBudget, let user = supabase.currentUser else { return }
        transaction.addedBy = user.id.uuidString.lowercased()
        let first = userName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        transaction.addedByName = first.isEmpty ? "Partner" : first
    }

    func deleteTransaction(id: String) {
        state.transactions.removeAll { $0.id == id }
        saveLocal()
        scheduleCloudSave()
        showToast("Transaction deleted.")
    }

    // MARK: - Recurring transactions (mirrors web postDueRecurring rules)

    private static func clampedDay(_ item: RecurringItem, year: Int, month: Int) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: calendar.date(from: comps) ?? Date())?.count ?? 28
        return min(item.dayOfMonth, daysInMonth)
    }

    /// Post recurring items due in the current real month that haven't posted yet.
    func postDueRecurring() {
        let monthKey = BudgetDefaults.currentMonthKey()
        let parts = monthKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let today = Calendar.current.component(.day, from: Date())
        var posted = 0
        var items = state.recurringItems
        for index in items.indices {
            let day = Self.clampedDay(items[index], year: parts[0], month: parts[1])
            if items[index].lastPostedMonth == monthKey || today < day { continue }
            let date = String(format: "%@-%02d", monthKey, day)
            state.transactions.insert(
                BudgetState.makeTransaction(
                    date: date,
                    type: items[index].type,
                    category: items[index].category,
                    description: items[index].description,
                    account: items[index].account,
                    amount: items[index].amount
                ),
                at: 0
            )
            items[index].lastPostedMonth = monthKey
            posted += 1
        }
        guard posted > 0 else { return }
        state.recurringItems = items
        saveLocal()
        scheduleCloudSave()
        showToast(posted == 1 ? "Posted 1 recurring transaction." : "Posted \(posted) recurring transactions.")
    }

    func nextRecurringDate(_ item: RecurringItem) -> Date {
        let monthKey = BudgetDefaults.currentMonthKey()
        let parts = monthKey.split(separator: "-").compactMap { Int($0) }
        let calendar = Calendar.current
        let today = calendar.component(.day, from: Date())
        guard parts.count == 2 else { return Date() }
        let (year, month) = (parts[0], parts[1])
        if item.lastPostedMonth != monthKey, today <= Self.clampedDay(item, year: year, month: month) {
            return calendar.date(from: DateComponents(year: year, month: month, day: Self.clampedDay(item, year: year, month: month))) ?? Date()
        }
        let nextYear = month == 12 ? year + 1 : year
        let nextMonth = month == 12 ? 1 : month + 1
        return calendar.date(from: DateComponents(year: nextYear, month: nextMonth, day: Self.clampedDay(item, year: nextYear, month: nextMonth))) ?? Date()
    }

    func addRecurring(type: String, category: String, description: String, account: String, amount: Double, dayOfMonth: Int) {
        let monthKey = BudgetDefaults.currentMonthKey()
        let parts = monthKey.split(separator: "-").compactMap { Int($0) }
        let today = Calendar.current.component(.day, from: Date())
        let item = RecurringItem(
            id: UUID().uuidString,
            type: type,
            category: category,
            description: description.isEmpty ? category : description,
            account: account,
            amount: amount,
            dayOfMonth: min(31, max(1, dayOfMonth)),
            // Past this month's day already? Start next month so we don't double a
            // bill the user probably logged by hand.
            lastPostedMonth: parts.count == 2 && today > Self.clampedDay(
                RecurringItem(id: "", type: type, category: category, description: description, account: account, amount: amount, dayOfMonth: min(31, max(1, dayOfMonth)), lastPostedMonth: ""),
                year: parts[0], month: parts[1]
            ) ? monthKey : ""
        )
        state.recurringItems.append(item)
        saveLocal()
        scheduleCloudSave()
        showToast("\(item.description) will post on day \(item.dayOfMonth) each month.")
        postDueRecurring()
        Task { await refreshBillReminders() }
    }

    func deleteRecurring(id: String) {
        state.recurringItems.removeAll { $0.id == id }
        saveLocal()
        scheduleCloudSave()
        showToast("Recurring item removed.")
        Task { await refreshBillReminders() }
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

    func deleteCategory(name: String) {
        guard let index = state.categories.firstIndex(where: { $0.name == name && $0.type == "Expense" }) else { return }
        let removed = state.categories.remove(at: index)
        saveLocal()
        scheduleCloudSave()
        showToast("\(removed.name) removed.")
    }

    func addSavingsGoal(name: String, target: Double, current: Double = 0) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard state.goals.count < 50 else {
            showToast("You can have up to 50 goals.")
            return
        }
        var goals = state.goals
        goals.append(
            SavingsGoal(
                id: UUID().uuidString,
                name: String(trimmed.prefix(40)),
                target: max(1, target),
                current: max(0, current)
            )
        )
        state.goals = goals
        saveLocal()
        scheduleCloudSave()
        showToast("Goal created.")
    }

    func updateSavingsGoal(id: String, name: String, target: Double, current: Double) {
        guard let index = state.goals.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.goals[index].name = String(trimmed.prefix(40))
        state.goals[index].target = max(1, target)
        state.goals[index].current = max(0, current)
        saveLocal()
        scheduleCloudSave()
        showToast("Goal updated.")
    }

    func addMoneyToGoal(id: String, amount: Double) {
        guard let index = state.goals.firstIndex(where: { $0.id == id }) else { return }
        guard amount > 0 else { return }
        state.goals[index].current = min(1_000_000_000, state.goals[index].current + amount)
        let done = state.goals[index].current >= state.goals[index].target
        let name = state.goals[index].name
        saveLocal()
        scheduleCloudSave()
        showToast(done ? "\(name) is fully funded!" : "Added \(currency(amount)) to \(name).")
    }

    func deleteSavingsGoal(id: String) {
        guard let index = state.goals.firstIndex(where: { $0.id == id }) else { return }
        state.goals.remove(at: index)
        saveLocal()
        scheduleCloudSave()
        showToast("Goal deleted.")
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
        publishWidgetSnapshot()
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

    // MARK: - Shared budgets

    private func teardownShared() async {
        await supabase.unsubscribeSharedBudget()
        sharedMembership = nil
        lastSharedAppliedAt = 0
        inviteLink = nil
        sharedMemberCount = nil
    }

    private func resolveSharedAndLoad(userId: UUID) async {
        await resolveSharedMembership()
        if sharedMembership != nil {
            await loadSharedState(userId: userId)
            await refreshSharedMemberCount()
        } else {
            await loadFromCloud(userId: userId)
        }
    }

    private func resolveSharedMembership() async {
        await teardownShared()
        if let pending = UserDefaults.standard.string(forKey: Self.pendingJoinKey),
           let token = UUID(uuidString: pending) {
            do {
                let budgetId = try await supabase.acceptBudgetInvite(token: token)
                sharedMembership = SharedMembership(id: budgetId, role: "member")
                showToast("You joined the shared budget!")
            } catch {
                showToast(supabase.friendlySharedError(error))
            }
            UserDefaults.standard.removeObject(forKey: Self.pendingJoinKey)
            hasPendingJoinInvite = false
        }
        if sharedMembership == nil {
            do {
                sharedMembership = try await supabase.fetchMySharedMembership()
            } catch {
                sharedMembership = nil
            }
        }
        if let membership = sharedMembership {
            await startSharedSubscription(budgetId: membership.id)
        }
    }

    private func loadSharedState(userId: UUID) async {
        guard let membership = sharedMembership else { return }
        do {
            let remote = try await supabase.fetchSharedBudget(budgetId: membership.id)
            let local = loadLocal(userId: userId)
            let remoteAt = remote?.updatedAt ?? 0
            let localAt = local?.updatedAt ?? 0
            if let remote, local == nil || remoteAt >= localAt {
                lastSharedAppliedAt = remote.updatedAt
                applyLoadedState(remote.state, updatedAt: remote.updatedAt, persistCleanup: true)
            } else if let local {
                applyLoadedState(local.state, updatedAt: local.updatedAt, persistCleanup: true)
                lastSharedAppliedAt = local.updatedAt
                if remote == nil || localAt > remoteAt {
                    await pushCloud(notifyOnFailure: false)
                }
            } else {
                state = BudgetDefaults.emptyState()
            }
            if cloudDirty {
                await pushCloud(notifyOnFailure: false)
            }
            postDueRecurring()
        } catch {
            if let local = loadLocal(userId: userId) {
                applyLoadedState(local.state, updatedAt: local.updatedAt, persistCleanup: false)
                postDueRecurring()
            }
            cloudDirty = true
            if !didNotifySyncFailure {
                didNotifySyncFailure = true
                showToast("Working offline — changes save on this device.")
            }
        }
    }

    private func startSharedSubscription(budgetId: UUID) async {
        await supabase.subscribeSharedBudget(budgetId: budgetId) { [weak self] in
            Task { @MainActor in
                await self?.applyRemoteSharedChange()
            }
        }
    }

    private func applyRemoteSharedChange() async {
        guard let membership = sharedMembership else { return }
        do {
            let remote = try await supabase.fetchSharedBudget(budgetId: membership.id)
            guard let remote, remote.updatedAt > lastSharedAppliedAt else { return }
            lastSharedAppliedAt = remote.updatedAt
            applyLoadedState(remote.state, updatedAt: remote.updatedAt, persistCleanup: true)
            await refreshBillReminders()
            showToast("Budget updated by your partner.")
        } catch {
            /* transient — next event or reload catches up */
        }
    }

    private func refreshSharedMemberCount() async {
        guard let membership = sharedMembership else {
            sharedMemberCount = nil
            return
        }
        do {
            let members = try await supabase.listBudgetMembers(budgetId: membership.id)
            sharedMemberCount = members.count
        } catch {
            sharedMemberCount = nil
        }
    }

    func shareThisBudget() async {
        guard !isInSharedBudget, supabase.currentUser != nil else { return }
        isSharedBusy = true
        sharedStatusMessage = "Setting up your shared budget…"
        defer { isSharedBusy = false }
        do {
            let first = userName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
            let name = first.isEmpty ? "Shared budget" : "\(first)'s shared budget"
            let budgetId = try await supabase.createSharedBudget(state: state, name: name)
            sharedMembership = SharedMembership(id: budgetId, role: "owner")
            lastSharedAppliedAt = Int64(Date().timeIntervalSince1970 * 1000)
            saveLocal()
            await startSharedSubscription(budgetId: budgetId)
            try await mintInviteLink()
            sharedStatusMessage = "Done — send your partner the link. It works once and expires in 7 days."
            await refreshSharedMemberCount()
        } catch {
            sharedStatusMessage = supabase.friendlyAuthError(error)
        }
    }

    func mintInviteLink() async throws {
        guard let membership = sharedMembership else { return }
        let token = try await supabase.createBudgetInvite(budgetId: membership.id)
        inviteLink = SupabaseService.inviteURL(token: token)
    }

    func createNewInviteLink() async {
        guard isSharedOwner else { return }
        isSharedBusy = true
        defer { isSharedBusy = false }
        do {
            try await mintInviteLink()
            sharedStatusMessage = "New invite link ready — works once, expires in 7 days."
        } catch {
            sharedStatusMessage = supabase.friendlyAuthError(error)
        }
    }

    func leaveSharedBudget() async {
        guard let membership = sharedMembership, let uid = supabase.currentUser?.id else { return }
        isSharedBusy = true
        defer { isSharedBusy = false }
        do {
            // Option A: keep shared snapshot minus partner's tagged entries.
            let keptTransactions = state.transactions
                .filter { tx in
                    guard let addedBy = tx.addedBy else { return true }
                    return addedBy.lowercased() == uid.uuidString.lowercased()
                }
                .map { tx -> BudgetTransaction in
                    var copy = tx
                    copy.addedBy = nil
                    copy.addedByName = nil
                    return copy
                }
            var kept = state
            kept.transactions = keptTransactions
            try await supabase.leaveSharedBudget(budgetId: membership.id)
            await teardownShared()
            state = kept
            saveLocal()
            await pushCloud(notifyOnFailure: true)
            sharedStatusMessage = nil
            showToast("Left the shared budget — your copy is saved.")
        } catch {
            sharedStatusMessage = supabase.friendlyAuthError(error)
        }
    }

    /// Re-fetch cloud when the app returns to foreground — never overwrite newer cloud with stale local.
    func refreshFromCloudIfNeeded() async {
        guard isAuthenticated, let userId = supabase.currentUser?.id else { return }
        if sharedMembership != nil {
            await refreshSharedFromCloud()
        } else {
            await refreshPersonalFromCloud(userId: userId)
        }
        if cloudDirty {
            await pushCloud(notifyOnFailure: false)
        }
    }

    private func refreshPersonalFromCloud(userId: UUID) async {
        do {
            let cloud = try await supabase.fetchBudget(userId: userId)
            let local = loadLocal(userId: userId)
            let cloudAt = cloud?.updatedAt ?? 0
            let localAt = local?.updatedAt ?? 0
            if let cloud, cloudAt > localAt {
                applyLoadedState(cloud.state, updatedAt: cloud.updatedAt, persistCleanup: true)
            } else if let local, let cloud, localAt > cloudAt, !cloudDirty {
                await pushCloud(notifyOnFailure: false)
            }
        } catch {
            /* quiet background refresh */
        }
    }

    private func refreshSharedFromCloud() async {
        guard let membership = sharedMembership else { return }
        do {
            let remote = try await supabase.fetchSharedBudget(budgetId: membership.id)
            guard let userId = supabase.currentUser?.id else { return }
            let local = loadLocal(userId: userId)
            let remoteAt = remote?.updatedAt ?? 0
            let localAt = local?.updatedAt ?? 0
            if let remote, remoteAt > localAt, remoteAt > lastSharedAppliedAt {
                lastSharedAppliedAt = remote.updatedAt
                applyLoadedState(remote.state, updatedAt: remote.updatedAt, persistCleanup: true)
            }
        } catch {
            /* quiet background refresh */
        }
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
            postDueRecurring()
        } catch {
            if let local = loadLocal(userId: userId) {
                applyLoadedState(local.state, updatedAt: local.updatedAt, persistCleanup: false)
                postDueRecurring()
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
              let data = try? JSONEncoder().encode(CloudBudgetPayload(state: state, updatedAt: localUpdatedAt, name: userName)) else {
            publishWidgetSnapshot()
            return
        }
        UserDefaults.standard.set(data, forKey: cacheKey(for: userId))
        publishWidgetSnapshot()
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
            if let membership = sharedMembership {
                let serverAt = try await supabase.pushSharedBudget(budgetId: membership.id, payload: payload)
                lastSharedAppliedAt = serverAt
                localUpdatedAt = serverAt
            } else {
                let serverAt = try await supabase.pushBudget(userId: userId, payload: payload)
                localUpdatedAt = serverAt
            }
            cloudDirty = false
            didNotifySyncFailure = false
            saveLocalKeepingTimestamp()
            publishWidgetSnapshot()
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
