import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var showSetup: Bool
    @Binding var showAddTransaction: Bool
    var onAddManually: (() -> Void)? = nil
    var onScanReceipt: (() -> Void)? = nil

    private var breakdownRows: [(category: BudgetCategory, spent: Double)] {
        Array(store.categorySpending.filter { $0.spent > 0 }.prefix(8))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    welcomeHeader

                    monthPicker

                    LazyVGrid(
                        columns: AdaptiveLayout.metricColumns(horizontalSizeClass: horizontalSizeClass),
                        spacing: AppTheme.md
                    ) {
                        MetricCard(
                            title: "Income",
                            value: currency(store.monthSummary.income),
                            subtitle: "This month",
                            valueColor: AppTheme.income,
                            emoji: "💵"
                        )
                        MetricCard(
                            title: "Spent",
                            value: currency(store.monthSummary.spent),
                            subtitle: "This month",
                            valueColor: AppTheme.expense,
                            emoji: "🧾"
                        )
                        MetricCard(
                            title: "Plan left",
                            value: currency(store.monthSummary.left),
                            subtitle: "Of your plan",
                            emoji: "🎯"
                        )
                        HStack(spacing: AppTheme.md) {
                            BudgetRingView(progress: store.monthSummary.usedRatio, label: "\(Int(store.monthSummary.usedRatio * 100))%")
                            VStack(alignment: .leading, spacing: AppTheme.xs) {
                                Text("Budget used")
                                    .font(.app(14, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Text(store.monthSummary.usedRatio > 1 ? "Over plan" : "On track")
                                    .font(.app(12, weight: .medium))
                                    .foregroundStyle(AppTheme.secondaryText)
                                Text("Cash left")
                                    .font(.app(12, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Text(currency(store.monthSummary.cashLeft))
                                    .font(.app(12, weight: .medium))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }
                        .appCard()
                    }

                    if let pay = store.payPeriodSummary {
                        payPeriodCard(pay)
                    }

                    categoryProgressSection
                    categoryBreakdownSection
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, AppTheme.lg)
                .padding(.bottom, AppTheme.xxl)
                .readableWidth()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
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

                        // Setup wand only before first-run completion; afterward use Settings.
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
        }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.xs) {
            Text(welcomeTitle)
                .font(.app(28, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
            Text(todaySubtitle)
                .font(.app(15, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var welcomeTitle: String {
        let name = store.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Welcome!" : "Welcome \(name)!"
    }

    private var todaySubtitle: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEE, MMMM d")
        return formatter.string(from: Date())
    }

    private var monthPicker: some View {
        HStack(spacing: AppTheme.sm) {
            Text("Month")
                .font(.app(14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.inputFill)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Previous month")

            Text(monthYearLabel)
                .font(.app(15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(minWidth: 120)
                .multilineTextAlignment(.center)

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.inputFill)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Next month")
        }
        .appCard()
    }

    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: store.selectedMonth)
    }

    private func shiftMonth(by value: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: value, to: store.selectedMonth) {
            store.selectedMonth = next
        }
    }

    private func payPeriodCard(_ pay: PayPeriodSummary) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.xs) {
                    Text("This pay period")
                        .font(.app(12, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .textCase(.uppercase)
                    Text(pay.rangeLabel)
                        .font(.app(18, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                Spacer()
                Text("📅")
                    .font(.app(28))
                    .frame(width: 48, height: 48)
                    .background(AppTheme.pastelBlue.opacity(0.45), in: Circle())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.sm) {
                miniStat("Income", currency(pay.income), AppTheme.income)
                miniStat("Spent", currency(pay.spent), AppTheme.expense)
                // Date range under Check left so month vs paycheck windows are obvious at a glance.
                miniStat("Check left", currency(pay.left), AppTheme.primaryText, subtitle: pay.rangeLabel)
            }
        }
        .appCard()
    }

    private func miniStat(_ title: String, _ value: String, _ color: Color, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.xs) {
            Text(title)
                .font(.app(12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.app(16, weight: .bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.app(11, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryProgressSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.md) {
            VStack(alignment: .leading, spacing: AppTheme.xs) {
                Text("Control")
                    .font(.app(12, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .textCase(.uppercase)
                Text("Category progress")
                    .font(.app(18, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            if store.categorySpending.isEmpty {
                Text("Set budgets or log spending to track progress.")
                    .font(.app(14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.vertical, AppTheme.sm)
            } else {
                LazyVGrid(
                    columns: AdaptiveLayout.categoryColumns(horizontalSizeClass: horizontalSizeClass),
                    spacing: AppTheme.md
                ) {
                    ForEach(store.categorySpending, id: \.category.id) { row in
                        VStack(alignment: .leading, spacing: AppTheme.sm) {
                            HStack {
                                Text(row.category.name)
                                    .font(.app(15, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Spacer()
                                GroupPill(group: row.category.group)
                            }
                            ProgressView(value: min(row.category.budget > 0 ? row.spent / row.category.budget : 0, 1))
                                .tint(row.spent > row.category.budget ? AppTheme.expense : AppTheme.primaryText)
                            Text("\(currencyDetailed(row.spent)) / \(currency(row.category.budget))")
                                .font(.app(12, weight: .medium))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding(.vertical, AppTheme.xs)
                    }
                }
            }
        }
        .appCard()
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppTheme.lg)
            } else {
                let maxSpent = breakdownRows.map(\.spent).max() ?? 1
                VStack(spacing: AppTheme.md) {
                    ForEach(Array(breakdownRows.enumerated()), id: \.element.category.id) { index, row in
                        categoryBreakdownRow(row: row, maxSpent: maxSpent, index: index)
                    }
                }
                .padding(.top, AppTheme.xs)
            }
        }
        .appCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spending by category")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.category.name), \(currencyDetailed(row.spent))")
    }
}
