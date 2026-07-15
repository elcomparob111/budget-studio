import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var showSetup: Bool
    @Binding var showAddTransaction: Bool
    var onAddManually: (() -> Void)? = nil
    var onScanReceipt: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    welcomeHeader

                    monthPicker

                    HStack(spacing: AppTheme.md) {
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
                    }

                    budgetUsedCard

                    if !upcomingBills.isEmpty {
                        upcomingSection
                    }

                    if let pay = store.payPeriodSummary {
                        payPeriodCard(pay)
                    }

                    categoryProgressSection
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, AppTheme.lg)
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

    /// Recurring items due within the next 14 days, soonest first (mirrors web).
    private var upcomingBills: [(item: RecurringItem, date: Date)] {
        let horizon = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        return store.state.recurringItems
            .map { (item: $0, date: store.nextRecurringDate($0)) }
            .filter { $0.date <= horizon }
            .sorted { $0.date < $1.date }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.md) {
            Text("Upcoming bills")
                .font(.app(16, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            ForEach(upcomingBills, id: \.item.id) { entry in
                HStack(spacing: AppTheme.md) {
                    Text(entry.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.app(13, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 56, alignment: .leading)
                    Text(entry.item.description)
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Text("\(entry.item.type == "Income" ? "+" : "")\(currency(entry.item.amount))")
                        .font(.app(15, weight: .bold))
                        .foregroundStyle(entry.item.type == "Income" ? AppTheme.income : AppTheme.primaryText)
                }
            }
        }
        .appCard()
    }

    /// Safe-to-spend hero: plan remaining for the selected month (matches web header).
    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.xs) {
            Text(currency(store.monthSummary.left))
                .font(.app(30, weight: .bold))
                .foregroundStyle(store.monthSummary.left < 0 ? AppTheme.expense : AppTheme.primaryText)
                .monospacedDigit()
            Text("Safe to spend in \(monthYearLabel)")
                .font(.app(15, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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

    /// Full width, not a grid cell: as the third item in a 2-up metric grid it
    /// filled only the left column, leaving half a row empty and squeezing the
    /// labels into two-line wraps.
    private var budgetUsedCard: some View {
        HStack(spacing: AppTheme.lg) {
            BudgetRingView(progress: store.monthSummary.usedRatio, label: "\(Int(store.monthSummary.usedRatio * 100))%")
            VStack(alignment: .leading, spacing: AppTheme.xs) {
                Text("Budget used")
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(store.monthSummary.usedRatio > 1 ? "Over plan" : "On track")
                    .font(.app(13, weight: .medium))
                    .foregroundStyle(store.monthSummary.usedRatio > 1 ? AppTheme.expense : AppTheme.secondaryText)
            }
            Spacer(minLength: AppTheme.md)
            VStack(alignment: .trailing, spacing: AppTheme.xs) {
                Text("Cash left")
                    .font(.app(13, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                Text(currency(store.monthSummary.cashLeft))
                    .font(.app(18, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func payPeriodCard(_ pay: PayPeriodSummary) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.sm) {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.xs) {
                    Text("This pay period")
                        .font(.app(12, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .textCase(.uppercase)
                    Text(pay.rangeLabel)
                        .font(.app(18, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    if let nextHint = store.nextPayPeriodHint {
                        Text(nextHint)
                            .font(.app(12, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
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
}
