import Foundation

enum BudgetCalculator {
    static func monthKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    /// Local calendar "today" as `yyyy-MM-dd` (avoids UTC drift from ISO8601).
    static func todayString(now: Date = Date(), calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: now)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        let day = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func monthSummary(state: BudgetState, month: String) -> MonthSummary {
        let monthTransactions = state.transactions.filter { $0.date.hasPrefix(month) }
        let income = monthTransactions.filter { $0.type == "Income" }.reduce(0) { $0 + $1.amount }
        let spent = monthTransactions.filter { $0.type == "Expense" }.reduce(0) { $0 + $1.amount }
        let budgeted = state.categories.filter { $0.type == "Expense" }.reduce(0) { $0 + $1.budget }
        let budgetLeft = budgeted - spent
        let cashLeft = income - spent
        let usedRatio = budgeted > 0 ? spent / budgeted : 0
        return MonthSummary(
            income: income,
            spent: spent,
            budgeted: budgeted,
            left: budgetLeft,
            cashLeft: cashLeft,
            usedRatio: usedRatio
        )
    }

    static func payPeriodSummary(state: BudgetState, month: String, now: Date = Date()) -> PayPeriodSummary? {
        guard let profile = state.setupProfile else { return nil }
        let today = todayString(now: now)
        // When browsing the current month, use today; otherwise use the 1st of that month
        // so the paycheck window matches the selected month (same as web).
        let referenceDate = month == String(today.prefix(7)) ? today : "\(month)-01"
        guard let period = payPeriod(for: referenceDate, profile: profile) else { return nil }

        let transactions = state.transactions.filter {
            dateInRange($0.date, start: period.start, end: period.end)
        }
        let loggedIncome = transactions.filter { $0.type == "Income" }.reduce(0) { $0 + $1.amount }
        // Show logged paycheck income when present; otherwise fall back to configured check amount.
        let income = loggedIncome > 0 ? loggedIncome : max(0, profile.payAmount)
        let spent = transactions.filter { $0.type == "Expense" }.reduce(0) { $0 + $1.amount }
        // Left must use the same income basis shown in the Income metric (not a hidden payAmount).
        let left = income - spent
        return PayPeriodSummary(
            rangeLabel: "\(formatShort(period.start)) – \(formatShort(period.end))",
            income: income,
            spent: spent,
            left: left
        )
    }

    /// Expense categories with activity this month or a budget — used by Overview progress.
    /// Idle $0/$0 rows are omitted; they reappear automatically when spent or budget becomes > 0.
    static func categorySpending(state: BudgetState, month: String) -> [(category: BudgetCategory, spent: Double)] {
        let monthTransactions = state.transactions.filter { $0.date.hasPrefix(month) && $0.type == "Expense" }
        return state.categories
            .filter { $0.type == "Expense" }
            .map { category in
                let spent = monthTransactions.filter { $0.category == category.name }.reduce(0) { $0 + $1.amount }
                return (category, spent)
            }
            .filter { $0.spent > 0 || $0.category.budget > 0 }
            .sorted {
                if $0.spent != $1.spent { return $0.spent > $1.spent }
                return $0.category.budget > $1.category.budget
            }
    }

    private static func payPeriod(for dateString: String, profile: SetupProfile) -> (start: String, end: String)? {
        guard let date = parseDate(dateString) else { return nil }
        let frequency = profile.payFrequency

        if frequency == "weekly" || frequency == "biweekly" {
            guard let nextPay = parseDate(profile.nextPayDate) else { return nil }
            let interval = frequency == "weekly" ? 7 : 14
            var anchor = nextPay
            while anchor > date {
                anchor = Calendar.current.date(byAdding: .day, value: -interval, to: anchor) ?? anchor
            }
            while Calendar.current.date(byAdding: .day, value: interval, to: anchor)! <= date {
                anchor = Calendar.current.date(byAdding: .day, value: interval, to: anchor) ?? anchor
            }
            let end = Calendar.current.date(byAdding: .day, value: interval - 1, to: anchor)!
            return (formatISO(anchor), formatISO(end))
        }

        if frequency == "semimonthly" {
            let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
            let day = comps.day ?? 1
            let isFirstHalf = day <= 15
            var startComps = comps
            startComps.day = isFirstHalf ? 1 : 16
            let start = Calendar.current.date(from: startComps)!
            if isFirstHalf {
                var endComps = comps
                endComps.day = 15
                let end = Calendar.current.date(from: endComps)!
                return (formatISO(start), formatISO(end))
            }
            let end = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: Calendar.current.date(from: DateComponents(year: comps.year, month: comps.month, day: 1))!)!
            return (formatISO(start), formatISO(end))
        }

        if frequency == "monthly" {
            let comps = Calendar.current.dateComponents([.year, .month], from: date)
            let start = Calendar.current.date(from: comps)!
            let end = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return (formatISO(start), formatISO(end))
        }

        return nil
    }

    private static func dateInRange(_ date: String, start: String, end: String) -> Bool {
        date >= start && date <= end
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private static func formatISO(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func formatShort(_ value: String) -> String {
        guard let date = parseDate(value) else { return value }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
