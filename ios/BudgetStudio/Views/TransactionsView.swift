import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var store: BudgetStore
    @Binding var showAddTransaction: Bool
    var onAddManually: (() -> Void)? = nil
    var onScanReceipt: (() -> Void)? = nil
    @State private var search = ""
    @State private var typeFilter = "All"
    @State private var categoryFilter: String?
    @State private var editingTransaction: BudgetTransaction?

    private var monthTransactions: [BudgetTransaction] {
        store.state.transactions.filter { $0.date.hasPrefix(store.monthKey) }
    }

    private var categoryChipNames: [String] {
        Array(Set(monthTransactions.map(\.category))).sorted()
    }

    private var rows: [BudgetTransaction] {
        monthTransactions
            .filter { typeFilter == "All" || $0.type == typeFilter }
            .filter { categoryFilter == nil || $0.category == categoryFilter }
            .filter {
                search.isEmpty ||
                $0.description.localizedCaseInsensitiveContains(search) ||
                $0.category.localizedCaseInsensitiveContains(search) ||
                $0.account.localizedCaseInsensitiveContains(search)
            }
            .sorted { $0.date > $1.date }
    }

    private var groupedRows: [(day: String, items: [BudgetTransaction])] {
        let grouped = Dictionary(grouping: rows, by: \.date)
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day]!.sorted { $0.amount > $1.amount })
        }
    }

    private var hasActiveFilters: Bool {
        !search.isEmpty || typeFilter != "All" || categoryFilter != nil
    }

    private var breakdownRows: [(category: BudgetCategory, spent: Double)] {
        Array(store.categorySpending.filter { $0.spent > 0 }.prefix(8))
    }

    private var monthNet: Double {
        store.monthSummary.income - store.monthSummary.spent
    }

    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: store.selectedMonth)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.xxl) {
                    heroComposition
                    filtersBlock

                    if rows.isEmpty {
                        emptyState
                    } else {
                        activityFeed
                    }

                    if !breakdownRows.isEmpty {
                        categoryBreakdownSection
                    }
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, AppTheme.md)
                .padding(.bottom, AppTheme.xxl)
                .readableWidth()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Activity")
                        .font(.app(17, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }
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

    // MARK: - Hero

    private var heroComposition: some View {
        VStack(alignment: .leading, spacing: AppTheme.xl) {
            VStack(alignment: .leading, spacing: AppTheme.sm) {
                Text("Net this month")
                    .font(.app(12, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Text(currency(monthNet))
                    .font(.app(48, weight: .bold))
                    .foregroundStyle(monthNet < 0 ? AppTheme.expense : AppTheme.primaryText)
                    .monospacedDigit()
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .contentTransition(.numericText())

                Text(monthYearLabel)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            HStack(alignment: .firstTextBaseline, spacing: AppTheme.xl) {
                heroInlineStat(label: "In", value: currency(store.monthSummary.income), color: AppTheme.income)
                heroInlineStat(label: "Out", value: currency(store.monthSummary.spent), color: AppTheme.expense)
                Spacer(minLength: 0)
                Text("\(rows.count) shown")
                    .font(.app(12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(AppTheme.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.pastelPink.opacity(0.45),
                            AppTheme.pastelBlue.opacity(0.4),
                            AppTheme.surface,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func heroInlineStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.app(11, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.8)
            Text(value)
                .font(.app(18, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Filters

    private var filtersBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.md) {
            searchField

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.sm) {
                    ForEach(["All", "Expense", "Income"], id: \.self) { filter in
                        filterChip(
                            title: filter,
                            selected: typeFilter == filter,
                            fill: AppTheme.pastelBlue.opacity(0.55)
                        ) {
                            typeFilter = filter
                        }
                    }
                }
            }

            if !categoryChipNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.sm) {
                        filterChip(
                            title: "All categories",
                            selected: categoryFilter == nil,
                            fill: AppTheme.pastelGreen.opacity(0.55)
                        ) {
                            categoryFilter = nil
                        }
                        ForEach(categoryChipNames, id: \.self) { name in
                            filterChip(
                                title: name,
                                selected: categoryFilter == name,
                                fill: AppTheme.pastelGreen.opacity(0.55)
                            ) {
                                categoryFilter = name
                            }
                        }
                    }
                }
            }
        }
    }

    private func filterChip(title: String, selected: Bool, fill: Color, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                action()
            }
        } label: {
            Text(title)
                .font(.app(13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? fill : AppTheme.surface)
                .clipShape(Capsule())
                .foregroundStyle(AppTheme.primaryText)
                .overlay(
                    Capsule()
                        .stroke(AppTheme.cardStroke, lineWidth: selected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: AppTheme.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
            TextField("Search description, category, or account", text: $search)
                .font(.app(15, weight: .medium))
                .appInputText()
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, AppTheme.lg)
        .padding(.vertical, 12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        )
    }

    // MARK: - Feed

    private var activityFeed: some View {
        VStack(alignment: .leading, spacing: AppTheme.lg) {
            Text("Ledger")
                .font(.app(13, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.8)

            VStack(alignment: .leading, spacing: AppTheme.xl) {
                ForEach(groupedRows, id: \.day) { group in
                    VStack(alignment: .leading, spacing: AppTheme.sm) {
                        Text(dayHeading(group.day))
                            .font(.app(13, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)

                        VStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    editingTransaction = item
                                } label: {
                                    TransactionRow(transaction: item)
                                        .padding(.horizontal, AppTheme.md)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)

                                if index < group.items.count - 1 {
                                    Divider()
                                        .opacity(0.3)
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(AppTheme.cardStroke, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private func dayHeading(_ value: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: value) else { return value }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let output = DateFormatter()
        output.setLocalizedDateFormatFromTemplate("EEEE, MMM d")
        return output.string(from: date)
    }

    // MARK: - Breakdown

    private var categoryBreakdownSection: some View {
        let maxSpent = breakdownRows.map(\.spent).max() ?? 1

        return VStack(alignment: .leading, spacing: AppTheme.md) {
            HStack {
                Text("Where it went")
                    .font(.app(13, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                if let top = breakdownRows.first {
                    Text(top.category.name)
                        .font(.app(12, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }

            VStack(spacing: AppTheme.md) {
                ForEach(Array(breakdownRows.enumerated()), id: \.element.category.id) { index, row in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            categoryFilter = row.category.name
                            typeFilter = "Expense"
                        }
                    } label: {
                        categoryBreakdownRow(row: row, maxSpent: maxSpent, index: index)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Filter activity by \(row.category.name)")
                }
            }
            .padding(AppTheme.lg)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            )
        }
    }

    private func categoryBreakdownRow(
        row: (category: BudgetCategory, spent: Double),
        maxSpent: Double,
        index: Int
    ) -> some View {
        let fraction = maxSpent > 0 ? row.spent / maxSpent : 0
        let barColor = AppTheme.chartBarColor(group: row.category.group, index: index)
        let selected = categoryFilter == row.category.name

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(barColor)
                    .frame(width: 8, height: 8)
                Text(row.category.name)
                    .font(.app(14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Spacer()
                Text(currencyDetailed(row.spent))
                    .font(.app(13, weight: .bold))
                    .foregroundStyle(selected ? AppTheme.primaryText : AppTheme.secondaryText)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.ringTrack)
                        .frame(height: 5)
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(4, geo.size.width * fraction), height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(.vertical, 4)
        .opacity(categoryFilter == nil || selected ? 1 : 0.45)
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.md) {
            Text(hasActiveFilters ? "Nothing matches" : "No activity yet")
                .font(.app(18, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
            Text(hasActiveFilters
                  ? "Try a different filter or search."
                  : "Add a transaction or scan a receipt.")
                .font(.app(14, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            if !hasActiveFilters {
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
        .padding(.horizontal, AppTheme.lg)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        )
    }
}

struct TransactionRow: View {
    @EnvironmentObject private var store: BudgetStore
    let transaction: BudgetTransaction

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.md) {
            Text(transaction.type == "Income" ? "💵" : "🧾")
                .font(.app(18))
                .frame(width: 36, height: 36)
                .background(
                    (transaction.type == "Income" ? AppTheme.pastelGreen : AppTheme.pastelPink).opacity(0.55),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.description.isEmpty ? transaction.category : transaction.description)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(transaction.category) · \(transaction.account)")
                        .font(.app(12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
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
            Spacer(minLength: AppTheme.xs)
            Text((transaction.type == "Income" ? "+" : "−") + currencyDetailed(transaction.amount))
                .font(.app(15, weight: .bold))
                .foregroundStyle(transaction.type == "Income" ? AppTheme.income : AppTheme.expense)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
