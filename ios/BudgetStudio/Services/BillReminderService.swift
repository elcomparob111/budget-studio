import Foundation
import UserNotifications

/// Local notifications for upcoming recurring expenses (bills).
/// No server/APNs — schedules on-device when the toggle is on and recurring items change.
@MainActor
final class BillReminderService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = BillReminderService()

    private static let enabledKey = "budget-studio-bill-reminders"
    private static let idPrefix = "bill-reminder-"
    /// Remind at 9:00 local on the due morning.
    private static let remindHour = 9
    private static let remindMinute = 0
    /// How many upcoming months to schedule per bill (app reopen refreshes the window).
    private static let monthsAhead = 3

    private let center = UNUserNotificationCenter.current()

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    func install() {
        center.delegate = self
    }

    /// Request alert permission. Returns true if authorized (or provisional).
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Clear + reschedule reminders from the current recurring list.
    func refresh(items: [RecurringItem]) async {
        await cancelAllPending()
        guard isEnabled else { return }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let expenses = items.filter { $0.type == "Expense" }
        for item in expenses {
            for date in upcomingDueDates(for: item, count: Self.monthsAhead) {
                await schedule(item: item, on: date)
            }
        }
    }

    func cancelAllPending() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Scheduling

    private func schedule(item: RecurringItem, on dueDate: Date) async {
        var calendar = Calendar.current
        calendar.timeZone = .current
        var comps = calendar.dateComponents([.year, .month, .day], from: dueDate)
        comps.hour = Self.remindHour
        comps.minute = Self.remindMinute

        guard let fireDate = calendar.date(from: comps), fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Bill due today"
        let amount = item.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        content.body = "\(item.description) · \(amount) — open Budget Studio to log it."
        content.sound = .default
        content.userInfo = ["recurringId": item.id]

        let triggerComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
        let monthKey = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
        let id = "\(Self.idPrefix)\(item.id)-\(monthKey)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Next `count` due mornings for a recurring item (uses the same day-of-month clamp as posting).
    private func upcomingDueDates(for item: RecurringItem, count: Int) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        var cursor = Date()
        for _ in 0..<count {
            guard let next = nextDueDate(for: item, after: cursor, calendar: calendar) else { break }
            dates.append(next)
            cursor = calendar.date(byAdding: .day, value: 1, to: next) ?? next
        }
        return dates
    }

    private func nextDueDate(for item: RecurringItem, after afterDate: Date, calendar: Calendar) -> Date? {
        let start = calendar.startOfDay(for: afterDate)
        var year = calendar.component(.year, from: start)
        var month = calendar.component(.month, from: start)
        for _ in 0..<14 {
            let day = clampedDay(item.dayOfMonth, year: year, month: month, calendar: calendar)
            guard let due = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
                return nil
            }
            if due >= start { return due }
            if month == 12 {
                month = 1
                year += 1
            } else {
                month += 1
            }
        }
        return nil
    }

    private func clampedDay(_ dayOfMonth: Int, year: Int, month: Int, calendar: Calendar) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        let daysInMonth = calendar.range(of: .day, in: .month, for: calendar.date(from: comps) ?? Date())?.count ?? 28
        return min(max(1, dayOfMonth), daysInMonth)
    }

    // MARK: - Foreground presentation

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
