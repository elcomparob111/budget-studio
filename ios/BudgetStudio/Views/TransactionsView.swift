import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var showAddTransaction: Bool
    var onAddManually: (() -> Void)? = nil
    var onScanReceipt: (() -> Void)? = nil
    @State private var search = ""
    @State private var typeFilter = "All"
    @State private var editingTransaction: BudgetTransaction?

    private var rows: [BudgetTransaction] {
        store.state.transactions
            .filter { $0.date.hasPrefix(store.monthKey) }
            .filter { typeFilter == "All" || $0.type == typeFilter }
            .filter {
                search.isEmpty ||
                $0.description.localizedCaseInsensitiveContains(search) ||
                $0.category.localizedCaseInsensitiveContains(search)
            }
            .sorted { $0.date > $1.date }
    }

    private var breakdownRows: [(category: BudgetCategory, spent: Double)] {
        Array(store.categorySpending.filter { $0.spent > 0 }.prefix(8))
    }

    private var monthNet: Double {
        store.monthSummary.income - store.monthSummary.spent
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    incomeVsSpentCard
                    categoryBreakdownSection

                    filterChips
                    searchField

                    if rows.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: AppTheme.sm) {
                            ForEach(rows) { item in
                                Button {
                                    editingTransaction = item
                                } label: {
                                    TransactionRow(transaction: item)
                                        .appCard()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, AppTheme.lg)
                .padding(.bottom, AppTheme.xxl)
                .readableWidth()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            if let onAddManually {
                                onAddManually()
                            } else {
                                showAddTransaction = true
                            }
                        } label: {
                            Label("Add manually", systemImage: "plus")
                        }
                        Button {
                            if let onScanReceipt {
                                onScanReceipt()
                            } else {
                                showAddTransaction = true
                            }
                        } label: {
                            Label("Scan receipt", systemImage: "doc.text.viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }
                    .accessibilityLabel("Add transaction")
                }
            }
            .sheet(item: $editingTransaction) { transaction in
                AddTransactionSheet(existing: transaction)
                    .appSheetChrome(detents: [.medium, .large])
            }
        }
    }

    private var incomeVsSpentCard: some View {
        let income = store.monthSummary.income
        let spent = store.monthSummary.spent
        let maxValue = max(income, spent, 1)

        return VStack(alignment: .leading, spacing: AppTheme.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppTheme.xs) {
                    Text("This month")
                        .font(.app(12, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .textCase(.uppercase)
                    Text("Income vs spent")
                        .font(.app(18, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                Spacer()
                Text("\(currency(monthNet)) net")
                    .font(.app(13, weight: .bold))
                    .foregroundStyle(monthNet < 0 ? AppTheme.expense : AppTheme.income)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.08), in: Capsule())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.sm) {
                cashStat("Income", currency(income), AppTheme.income)
                cashStat("Spent", currency(spent), AppTheme.expense)
                cashStat("Net", currency(monthNet), monthNet < 0 ? AppTheme.expense : AppTheme.primaryText)
            }

            if income > 0 || spent > 0 {
                VStack(spacing: AppTheme.sm) {
                    cashflowBar(label: "Income", value: income, maxValue: maxValue, color: AppTheme.income)
                    cashflowBar(label: "Spent", value: spent, maxValue: maxValue, color: AppTheme.expense)
                }
            } else {
                Text("No income or spending logged for this month yet.")
                    .font(.app(14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.vertical, AppTheme.sm)
            }
        }
        .appCard()
    }

    private func cashStat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.xs) {
            Text(title)
                .font(.app(12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.app(16, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.md)
        .background(AppTheme.inputFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func cashflowBar(label: String, value: Double, maxValue: Double, color: Color) -> some View {
        HStack(spacing: AppTheme.md) {
            Text(label)
                .font(.app(13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 64, alignment: .leading)
            GeometryReader { geo in
                let width = max(8, geo.size.width * (value / maxValue))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color)
                    .frame(width: width, height: 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 18)
            Text(currency(value))
                .font(.app(12, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: 64, alignment: .trailing)
        }
    }

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppTheme.xs) {
                    Text("Spending")
                        .font(.app(12, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .textCase(.uppercase)
                    Text("Category breakdown")
                        .font(.app(18, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                Spacer(minLength: AppTheme.sm)
                if let top = breakdownRows.first {
                    Text("\(top.category.name): \(currencyDetailed(top.spent))")
                        .font(.app(12, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.08), in: Capsule())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Text("No spending yet")
                        .font(.app(12, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.08), in: Capsule())
                }
            }

            if breakdownRows.isEmpty {
                Text("No spending logged for this month.")
                    .font(.app(14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.vertical, AppTheme.sm)
            } else {
                let maxSpent = breakdownRows.map(\.spent).max() ?? 1
                VStack(spacing: AppTheme.md) {
                    ForEach(Array(breakdownRows.enumerated()), id: \.element.category.id) { index, row in
                        categoryBreakdownRow(row: row, maxSpent: maxSpent, index: index)
                    }
                }
            }
        }
        .appCard()
    }

    private func categoryBreakdownRow(
        row: (category: BudgetCategory, spent: Double),
        maxSpent: Double,
        index: Int
    ) -> some View {
        let fraction = maxSpent > 0 ? row.spent / maxSpent : 0
        let barColor = AppTheme.chartBarColor(group: row.category.group, index: index)

        return HStack(spacing: AppTheme.md) {
            Text(row.category.name)
                .font(.app(13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: horizontalSizeClass == .regular ? 120 : 88, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            GeometryReader { geo in
                let width = max(8, geo.size.width * fraction)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(barColor)
                    .frame(width: width, height: 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 18)

            Text(currencyDetailed(row.spent))
                .font(.app(12, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: horizontalSizeClass == .regular ? 72 : 64, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var filterChips: some View {
        HStack(spacing: AppTheme.sm) {
            ForEach(["All", "Expense", "Income"], id: \.self) { filter in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        typeFilter = filter
                    }
                } label: {
                    Text(filter)
                        .font(.app(13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(typeFilter == filter ? AppTheme.pastelBlue.opacity(0.55) : Color.gray.opacity(0.08))
                        .clipShape(Capsule())
                        .foregroundStyle(AppTheme.primaryText)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var searchField: some View {
        HStack(spacing: AppTheme.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
            TextField("Search transactions", text: $search)
                .font(.app(16, weight: .medium))
                .appInputText()
        }
        .padding(.horizontal, AppTheme.lg)
        .padding(.vertical, AppTheme.md)
        .background(AppTheme.inputFill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.md) {
            Text("📭")
                .font(.app(40))
                .frame(width: 70, height: 70)
                .background(AppTheme.pastelOrange.opacity(0.4), in: Circle())
                .accessibilityHidden(true)
            Text(search.isEmpty && typeFilter == "All" ? "No transactions yet" : "Nothing matches")
                .font(.app(18, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
            Text(search.isEmpty && typeFilter == "All"
                  ? "Add one for this month, or scan a receipt."
                  : "Try a different filter or search.")
                .font(.app(14, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            if search.isEmpty && typeFilter == "All" {
                Button {
                    if let onAddManually {
                        onAddManually()
                    } else {
                        showAddTransaction = true
                    }
                } label: {
                    Text("Add transaction")
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 220)
                .padding(.top, AppTheme.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.xxl)
        .appCard()
    }
}

struct TransactionRow: View {
    @EnvironmentObject private var store: BudgetStore
    let transaction: BudgetTransaction

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.md) {
            Text(transaction.type == "Income" ? "💵" : "🧾")
                .font(.app(20))
                .frame(width: 40, height: 40)
                .background(
                    (transaction.type == "Income" ? AppTheme.pastelGreen : AppTheme.pastelPink).opacity(0.55),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: AppTheme.xs) {
                Text(transaction.description.isEmpty ? transaction.category : transaction.description)
                    .font(.app(16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                HStack(spacing: 6) {
                    Text("\(transaction.category) · \(transaction.account)")
                        .font(.app(12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                    if let author = store.authorLabel(for: transaction) {
                        Text(author)
                            .font(.app(11, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.pastelBlue.opacity(0.55))
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: AppTheme.xs) {
                Text((transaction.type == "Income" ? "+" : "-") + currencyDetailed(transaction.amount))
                    .font(.app(15, weight: .bold))
                    .foregroundStyle(transaction.type == "Income" ? AppTheme.income : AppTheme.expense)
                Text(formatDate(transaction.date))
                    .font(.app(12, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func formatDate(_ value: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: value) else { return value }
        let output = DateFormatter()
        output.dateStyle = .medium
        return output.string(from: date)
    }
}
