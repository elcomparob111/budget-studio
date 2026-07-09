import Foundation

enum BudgetCalculator {
    static func monthKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    static func monthSummary(state: BudgetState, month: String) -> MonthSummary {
        let monthTransactions = state.transactions.filter { $0.date.hasPrefix(month) }
        let income = monthTransactions.filter { $0.type == "Income" }.reduce(0) { $0 + $1.amount }
        let spent = monthTransactions.filter { $0.type == "Expense" }.reduce(0) { $0 + $1.amount }
        let budgeted = state.categories.filter { $0.type == "Expense" }.reduce(0) { $0 + $1.budget }
        let left = budgeted - spent
        let usedRatio = budgeted > 0 ? spent / budgeted : 0
        return MonthSummary(income: income, spent: spent, budgeted: budgeted, left: left, usedRatio: usedRatio)
    }

    static func payPeriodSummary(state: BudgetState, month: String) -> PayPeriodSummary? {
        guard let profile = state.setupProfile else { return nil }
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let todayString = String(today)
        guard let period = payPeriod(for: todayString, profile: profile) else { return nil }

        let transactions = state.transactions.filter {
            dateInRange($0.date, start: period.start, end: period.end)
        }
        let income = transactions.filter { $0.type == "Income" }.reduce(0) { $0 + $1.amount }
        let spent = transactions.filter { $0.type == "Expense" }.reduce(0) { $0 + $1.amount }
        let left = profile.payAmount - spent
        return PayPeriodSummary(
            rangeLabel: "\(formatShort(period.start)) – \(formatShort(period.end))",
            income: income,
            spent: spent,
            left: left
        )
    }

    static func categorySpending(state: BudgetState, month: String) -> [(category: BudgetCategory, spent: Double)] {
        let monthTransactions = state.transactions.filter { $0.date.hasPrefix(month) && $0.type == "Expense" }
        return state.categories
            .filter { $0.type == "Expense" }
            .map { category in
                let spent = monthTransactions.filter { $0.category == category.name }.reduce(0) { $0 + $1.amount }
                return (category, spent)
            }
            .sorted { $0.spent > $1.spent }
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
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private static func formatISO(_ date: Date) -> String {
        let formatter = DateFormatter()
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
