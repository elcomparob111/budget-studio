import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: BudgetStore
    @Binding var showSetup: Bool
    @Binding var showAddTransaction: Bool
    var onAddManually: (() -> Void)? = nil
    var onScanReceipt: (() -> Void)? = nil
    @State private var expandedCategoryName: String?
    @State private var editingTransaction: BudgetTransaction?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.xxl) {
                    heroComposition

                    if !upcomingBills.isEmpty {
                        upcomingSection
                    }

                    categoryProgressSection
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityLabel("Budget Studio")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
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

                        if !store.state.setupComplete {
                            Button {
                                showSetup = true
                            } label: {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .frame(width: 36, height: 36)
                                    .background(AppTheme.surface)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                            }
                            .accessibilityLabel("Open setup")
                        }
                    }
                }
            }
            .sheet(item: $editingTransaction) { transaction in
                AddTransactionSheet(existing: transaction)
                    .appSheetChrome(detents: [.medium, .large])
            }
            .onChange(of: store.monthKey) { _, _ in
                expandedCategoryName = nil
            }
        }
    }

    // MARK: - Hero composition (one viewport, Check left first)

    private var heroAmount: Double {
        store.payPeriodSummary?.left ?? store.monthSummary.cashLeft
    }

    private var periodIncome: Double {
        store.payPeriodSummary?.income ?? store.monthSummary.income
    }

    private var periodSpent: Double {
        store.payPeriodSummary?.spent ?? store.monthSummary.spent
    }

    private var checkSpentRatio: Double {
        periodIncome > 0 ? periodSpent / periodIncome : 0
    }

    private var heroComposition: some View {
        VStack(alignment: .leading, spacing: AppTheme.xl) {
            HStack(alignment: .top, spacing: AppTheme.lg) {
                VStack(alignment: .leading, spacing: AppTheme.sm) {
                    Text("Check left")
                        .font(.app(12, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .textCase(.uppercase)
                        .tracking(1.2)

                    Text(currency(heroAmount))
                        .font(.app(48, weight: .bold))
                        .foregroundStyle(heroAmount < 0 ? AppTheme.expense : AppTheme.primaryText)
                        .monospacedDigit()
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                        .contentTransition(.numericText())

                    periodCaption
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                checkRing
            }

            HStack(alignment: .firstTextBaseline, spacing: AppTheme.xl) {
                heroInlineStat(label: "In", value: currency(periodIncome), color: AppTheme.income)
                heroInlineStat(label: "Out", value: currency(periodSpent), color: AppTheme.expense)
                Spacer(minLength: 0)
                monthStepper
            }

            monthPlanLine
        }
        .padding(AppTheme.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(heroWash)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var heroWash: some ShapeStyle {
        LinearGradient(
            colors: [
                AppTheme.pastelBlue.opacity(0.55),
                AppTheme.pastelGreen.opacity(0.35),
                AppTheme.surface,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var periodCaption: some View {
        if let pay = store.payPeriodSummary {
            VStack(alignment: .leading, spacing: 4) {
                Text(pay.rangeLabel)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                if let nextHint = store.nextPayPeriodHint {
                    Text(nextHint)
                        .font(.app(12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        } else {
            Text(monthYearLabel)
                .font(.app(15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    private var checkRing: some View {
        let ratio = checkSpentRatio
        let over = ratio > 1

        return ZStack {
            Circle()
                .stroke(AppTheme.ringTrack, lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(max(ratio, 0), 1))
                .stroke(
                    over ? AppTheme.expense : AppTheme.primaryText,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: ratio)

            VStack(spacing: 2) {
                Text("\(Int((min(ratio, 9.99) * 100).rounded()))%")
                    .font(.app(16, weight: .bold))
                    .foregroundStyle(over ? AppTheme.expense : AppTheme.primaryText)
                    .monospacedDigit()
                Text("spent")
                    .font(.app(10, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .textCase(.uppercase)
            }
        }
        .frame(width: 84, height: 84)
        .accessibilityLabel("\(Int((min(ratio, 9.99) * 100).rounded())) percent of check spent")
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

    private var monthStepper: some View {
        HStack(spacing: AppTheme.sm) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    shiftMonth(by: -1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.surface.opacity(0.85))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Previous month")

            Text(shortMonthLabel)
                .font(.app(13, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(minWidth: 72)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    shiftMonth(by: 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.surface.opacity(0.85))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Next month")
        }
    }

    private var monthPlanLine: some View {
        let ratio = store.monthSummary.usedRatio
        let over = ratio > 1

        return VStack(alignment: .leading, spacing: AppTheme.sm) {
            HStack {
                Text("Month plan")
                    .font(.app(12, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text(over ? "Over · \(Int(ratio * 100))%" : "\(Int(ratio * 100))% used")
                    .font(.app(12, weight: .semibold))
                    .foregroundStyle(over ? AppTheme.expense : AppTheme.primaryText)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.surface.opacity(0.7))
                        .frame(height: 6)
                    Capsule()
                        .fill(over ? AppTheme.expense : AppTheme.primaryText)
                        .frame(width: max(6, geo.size.width * min(max(ratio, 0), 1)), height: 6)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: ratio)
                }
            }
            .frame(height: 6)
        }
    }

    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: store.selectedMonth)
    }

    private var shortMonthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
        return formatter.string(from: store.selectedMonth)
    }

    private func shiftMonth(by value: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: value, to: store.selectedMonth) {
            store.selectedMonth = next
        }
    }

    // MARK: - Upcoming

    private var upcomingBills: [(item: RecurringItem, date: Date)] {
        let horizon = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        return store.state.recurringItems
            .map { (item: $0, date: store.nextRecurringDate($0)) }
            .filter { $0.date <= horizon }
            .sorted { $0.date < $1.date }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.md) {
            Text("Coming up")
                .font(.app(13, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.8)

            ForEach(upcomingBills.prefix(4), id: \.item.id) { entry in
                HStack(spacing: AppTheme.md) {
                    Text(entry.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.app(13, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 48, alignment: .leading)
                    Text(entry.item.description)
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Text("\(entry.item.type == "Income" ? "+" : "−")\(currency(entry.item.amount))")
                        .font(.app(15, weight: .bold))
                        .foregroundStyle(entry.item.type == "Income" ? AppTheme.income : AppTheme.primaryText)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Categories by group

    private var groupedCategories: [(group: String, rows: [(category: BudgetCategory, spent: Double)])] {
        let order = ["Needs", "Wants", "Savings"]
        let grouped = Dictionary(grouping: store.categorySpending) { $0.category.group }
        var result: [(group: String, rows: [(category: BudgetCategory, spent: Double)])] = []
        for key in order {
            if let rows = grouped[key], !rows.isEmpty {
                result.append((key, rows))
            }
        }
        for (key, rows) in grouped where !order.contains(key) && !rows.isEmpty {
            result.append((key, rows))
        }
        return result
    }

    private var categoryProgressSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.lg) {
            Text("Where it went")
                .font(.app(13, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.8)

            if store.categorySpending.isEmpty {
                Text("Set budgets or log spending to track progress.")
                    .font(.app(14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: AppTheme.xl) {
                    ForEach(groupedCategories, id: \.group) { section in
                        VStack(alignment: .leading, spacing: AppTheme.sm) {
                            HStack(spacing: AppTheme.sm) {
                                Text(AppTheme.groupEmoji(section.group))
                                    .font(.app(14))
                                Text(section.group)
                                    .font(.app(14, weight: .bold))
                                    .foregroundStyle(AppTheme.primaryText)
                            }

                            VStack(spacing: 0) {
                                ForEach(Array(section.rows.enumerated()), id: \.element.category.id) { index, row in
                                    categoryProgressSummary(row)

                                    if expandedCategoryName == row.category.name {
                                        expandedCategoryPanel(row)
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                    }

                                    if index < section.rows.count - 1 {
                                        Divider()
                                            .opacity(0.3)
                                            .padding(.leading, 28)
                                    }
                                }
                            }
                            .padding(.horizontal, AppTheme.md)
                            .padding(.vertical, AppTheme.xs)
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
    }

    private func categoryProgressSummary(_ row: (category: BudgetCategory, spent: Double)) -> some View {
        let name = row.category.name
        let isExpanded = expandedCategoryName == name
        let ratio = row.category.budget > 0 ? row.spent / row.category.budget : 0
        let over = row.spent > row.category.budget && row.category.budget > 0
        let tint = AppTheme.groupTint(row.category.group)

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                expandedCategoryName = isExpanded ? nil : name
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: AppTheme.md) {
                    Circle()
                        .fill(tint)
                        .frame(width: 9, height: 9)

                    Text(name)
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: AppTheme.xs)

                    Text(currencyDetailed(row.spent))
                        .font(.app(14, weight: .bold))
                        .foregroundStyle(over ? AppTheme.expense : AppTheme.primaryText)
                        .monospacedDigit()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.ringTrack)
                            .frame(height: 4)
                        Capsule()
                            .fill(over ? AppTheme.expense : tint)
                            .frame(width: max(3, geo.size.width * min(ratio, 1)), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.leading, 25)

                Text("of \(currency(row.category.budget))")
                    .font(.app(11, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.leading, 25)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isExpanded ? "Collapse expenses" : "Show expenses")
    }

    private func expandedCategoryPanel(_ row: (category: BudgetCategory, spent: Double)) -> some View {
        let expenses = expenses(for: row.category.name)

        return VStack(alignment: .leading, spacing: 0) {
            if expenses.isEmpty {
                Text("No expenses this month.")
                    .font(.app(13, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.vertical, AppTheme.sm)
                    .padding(.leading, 25)
            } else {
                ForEach(Array(expenses.enumerated()), id: \.element.id) { index, item in
                    Button {
                        editingTransaction = item
                    } label: {
                        categoryExpenseRow(item)
                    }
                    .buttonStyle(.plain)

                    if index < expenses.count - 1 {
                        Divider()
                            .opacity(0.22)
                            .padding(.leading, 25)
                    }
                }
            }
        }
        .padding(.bottom, 6)
        .background(AppTheme.inputFill.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func expenses(for categoryName: String) -> [BudgetTransaction] {
        store.state.transactions
            .filter {
                $0.type == "Expense" &&
                $0.category == categoryName &&
                $0.date.hasPrefix(store.monthKey)
            }
            .sorted { $0.date > $1.date }
    }

    private func categoryExpenseRow(_ item: BudgetTransaction) -> some View {
        HStack(spacing: AppTheme.sm) {
            Text(item.description.isEmpty ? item.category : item.description)
                .font(.app(14, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .padding(.leading, 25)
            Spacer(minLength: AppTheme.xs)
            Text(formatExpenseDate(item.date))
                .font(.app(12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
            Text(currencyDetailed(item.amount))
                .font(.app(13, weight: .bold))
                .foregroundStyle(AppTheme.expense)
                .monospacedDigit()
                .frame(minWidth: 64, alignment: .trailing)
                .padding(.trailing, AppTheme.sm)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func formatExpenseDate(_ value: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: value) else { return value }
        let output = DateFormatter()
        output.setLocalizedDateFormatFromTemplate("MMM d")
        return output.string(from: date)
    }
}
