import Foundation

struct BudgetCategory: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var type: String
    var group: String
    var budget: Double
}

struct BudgetTransaction: Codable, Identifiable, Hashable {
    var id: String
    var date: String
    var type: String
    var category: String
    var description: String
    var account: String
    var amount: Double
    /// Shared-budget authorship (optional; absent on personal/older rows).
    /// Present so iOS round-trips it instead of stripping web-set values on sync.
    var addedBy: String? = nil
    var addedByName: String? = nil
}

struct SetupProfile: Codable, Hashable {
    var presetId: String
    var income: Double
    var payAmount: Double
    var payFrequency: String
    var nextPayDate: String
    var completedAt: String?
    var demo: Bool?
}

/// Mirrors the web app's recurring shape exactly (field names are the JSON contract).
struct RecurringItem: Codable, Identifiable, Hashable {
    var id: String
    var type: String
    var category: String
    var description: String
    var account: String
    var amount: Double
    var dayOfMonth: Int
    var lastPostedMonth: String
}

/// Mirrors web `savingsGoals` JSON ({ id, name, target, current }).
struct SavingsGoal: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var target: Double
    var current: Double
}

struct BudgetState: Codable, Hashable {
    var categories: [BudgetCategory]
    var transactions: [BudgetTransaction]
    /// Optional so caches written before recurring existed still decode.
    var recurring: [RecurringItem]?
    /// Optional so older caches / web payloads without goals still decode.
    var savingsGoals: [SavingsGoal]?
    var setupComplete: Bool
    var setupProfile: SetupProfile?

    var recurringItems: [RecurringItem] {
        get { recurring ?? [] }
        set { recurring = newValue }
    }

    var goals: [SavingsGoal] {
        get { savingsGoals ?? [] }
        set { savingsGoals = newValue }
    }
}

struct MonthSummary {
    var income: Double
    var spent: Double
    var budgeted: Double
    /// Planned expense budgets minus month spent (budget remaining).
    var left: Double
    /// Logged month income minus month spent (cash remaining).
    var cashLeft: Double
    var usedRatio: Double
}

struct PayPeriodSummary {
    var rangeLabel: String
    var income: Double
    var spent: Double
    /// Pay-period income (logged, else configured check amount) minus period spent.
    var left: Double
}

struct PayPeriodPreview: Identifiable {
    var start: String
    var end: String
    var rangeLabel: String
    var isCurrent: Bool

    var id: String { start }
}

enum BudgetDefaults {
    static let accounts = ["Checking", "Credit Card", "Savings", "Cash", "Investment", "Venmo", "Other"]

    static func emptyState() -> BudgetState {
        BudgetState(
            categories: defaultCategories.map {
                BudgetCategory(
                    name: $0.name,
                    type: $0.type,
                    group: $0.group,
                    budget: $0.type == "Expense" ? 0 : $0.budget
                )
            },
            transactions: [],
            setupComplete: false,
            setupProfile: nil
        )
    }

    static func currentMonthKey(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    static func demoState() -> BudgetState {
        BudgetState(
            categories: defaultCategories,
            transactions: demoTransactions,
            // lastPostedMonth = current month so demo data doesn't auto-post on load.
            recurring: [
                RecurringItem(
                    id: "demo-recurring-rent",
                    type: "Expense",
                    category: "Housing",
                    description: "Rent",
                    account: "Checking",
                    amount: 1800,
                    dayOfMonth: 1,
                    lastPostedMonth: currentMonthKey()
                ),
                RecurringItem(
                    id: "demo-recurring-internet",
                    type: "Expense",
                    category: "Utilities",
                    description: "Internet bill",
                    account: "Checking",
                    amount: 60,
                    dayOfMonth: 25,
                    lastPostedMonth: ""
                ),
            ],
            savingsGoals: [
                SavingsGoal(id: "demo-goal-emergency", name: "Emergency fund", target: 3000, current: 750),
            ],
            setupComplete: true,
            setupProfile: SetupProfile(
                presetId: "single",
                income: 4550,
                payAmount: 2100,
                payFrequency: "biweekly",
                nextPayDate: "2026-07-10",
                completedAt: ISO8601DateFormatter().string(from: Date()),
                demo: true
            )
        )
    }

    private static let defaultCategories: [BudgetCategory] = [
        .init(name: "Salary", type: "Income", group: "Income", budget: 0),
        .init(name: "Side Income", type: "Income", group: "Income", budget: 0),
        .init(name: "Interest", type: "Income", group: "Income", budget: 0),
        .init(name: "Refund", type: "Income", group: "Income", budget: 0),
        .init(name: "Housing", type: "Expense", group: "Needs", budget: 1800),
        .init(name: "Utilities", type: "Expense", group: "Needs", budget: 250),
        .init(name: "Cell Phone", type: "Expense", group: "Needs", budget: 90),
        .init(name: "Groceries", type: "Expense", group: "Needs", budget: 650),
        .init(name: "Transportation", type: "Expense", group: "Needs", budget: 400),
        .init(name: "Insurance", type: "Expense", group: "Needs", budget: 250),
        .init(name: "Healthcare", type: "Expense", group: "Needs", budget: 200),
        .init(name: "Debt Payments", type: "Expense", group: "Needs", budget: 300),
        .init(name: "Dining Out", type: "Expense", group: "Wants", budget: 350),
        .init(name: "Subscriptions", type: "Expense", group: "Wants", budget: 100),
        .init(name: "Shopping", type: "Expense", group: "Wants", budget: 300),
        .init(name: "Entertainment", type: "Expense", group: "Wants", budget: 200),
        .init(name: "Travel", type: "Expense", group: "Wants", budget: 250),
        .init(name: "Personal Care", type: "Expense", group: "Wants", budget: 150),
        .init(name: "Education", type: "Expense", group: "Wants", budget: 100),
        .init(name: "Savings/Investing", type: "Expense", group: "Savings", budget: 500),
        .init(name: "Emergency Fund", type: "Expense", group: "Savings", budget: 300),
    ]

    private static let demoTransactions: [BudgetTransaction] = [
        .init(id: UUID().uuidString, date: "2026-07-01", type: "Income", category: "Salary", description: "Paycheck", account: "Checking", amount: 4200),
        .init(id: UUID().uuidString, date: "2026-07-01", type: "Expense", category: "Housing", description: "Rent", account: "Checking", amount: 1800),
        .init(id: UUID().uuidString, date: "2026-07-02", type: "Expense", category: "Groceries", description: "Weekly groceries", account: "Credit Card", amount: 128.47),
        .init(id: UUID().uuidString, date: "2026-07-05", type: "Expense", category: "Cell Phone", description: "Mobile phone bill", account: "Checking", amount: 92.45),
        .init(id: UUID().uuidString, date: "2026-07-07", type: "Income", category: "Side Income", description: "Freelance project", account: "Checking", amount: 350),
        .init(id: UUID().uuidString, date: "2026-07-08", type: "Expense", category: "Emergency Fund", description: "Savings transfer", account: "Savings", amount: 300),
    ]
}

extension BudgetState {
    static func makeTransaction(
        date: String,
        type: String,
        category: String,
        description: String,
        account: String,
        amount: Double
    ) -> BudgetTransaction {
        BudgetTransaction(
            id: UUID().uuidString,
            date: date,
            type: type,
            category: category,
            description: description,
            account: account,
            amount: amount
        )
    }
}
