import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var store: BudgetStore
    @Binding var showAddTransaction: Bool
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
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
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteTransaction(id: item.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
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
                    Button {
                        showAddTransaction = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .sheet(item: $editingTransaction) { transaction in
                AddTransactionSheet(existing: transaction)
                    .appSheetChrome(detents: [.medium, .large])
            }
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
            Text("No transactions yet")
                .font(.app(18, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
            Text("Add your first one for this month.")
                .font(.app(14, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.xxl)
        .appCard()
    }
}

struct TransactionRow: View {
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
                Text("\(transaction.category) · \(transaction.account)")
                    .font(.app(12, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
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
