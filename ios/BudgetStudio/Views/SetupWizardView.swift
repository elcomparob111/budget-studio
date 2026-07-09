import SwiftUI

struct SetupWizardView: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var payAmountText = ""
    @State private var payFrequency = "biweekly"
    @State private var nextPayDate = Date()
    @State private var selectedCategories: Set<String> = [
        "Housing", "Utilities", "Groceries", "Transportation", "Dining Out", "Emergency Fund"
    ]
    @State private var customCategoryName = ""
    @State private var customCategoryGroup = "Needs"
    @State private var customCategoryMessage = ""

    private let frequencies = [
        ("weekly", "Weekly"),
        ("biweekly", "Biweekly"),
        ("semimonthly", "Twice / mo"),
        ("monthly", "Monthly"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.xl) {
                ProgressView(value: Double(step + 1), total: 3)
                    .tint(AppTheme.primaryText)
                    .padding(.horizontal, AppTheme.pagePadding)
                    .readableWidth(AdaptiveLayout.formMaxWidth)

                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: incomeStep
                    default: categoriesStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                HStack {
                    if step > 0 {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.2)) { step -= 1 }
                        }
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(AppTheme.inputFill)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    Spacer()
                    Button(step < 2 ? "Continue" : "Finish") {
                        if step < 2 {
                            withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
                        } else {
                            finish()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(width: 140)
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.bottom, AppTheme.lg)
                .readableWidth(AdaptiveLayout.formMaxWidth)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .decimalPadDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.state.setupComplete ? "Close" : "Skip") {
                        if !store.state.setupComplete {
                            store.markSetupCompleteIfNeeded()
                        }
                        dismiss()
                    }
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                }
            }
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.lg) {
            Text("🪄")
                .font(.app(40))
                .frame(width: 70, height: 70)
                .background(AppTheme.pastelPurple.opacity(0.45), in: Circle())
            Text("Set up your budget in under 2 minutes.")
                .font(.app(24, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
            Text("Answer a few plain-language questions and Budget Studio will build a starting budget for you.")
                .font(.app(16, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
            Button("Try demo budget instead") {
                store.loadDemo()
                dismiss()
            }
            .font(.app(15, weight: .semibold))
            .foregroundStyle(AppTheme.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.inputFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, AppTheme.pagePadding)
        .padding(.top, AppTheme.lg)
        .readableWidth(AdaptiveLayout.formMaxWidth)
    }

    private var incomeStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.lg) {
            Text("Your paycheck")
                .font(.app(22, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            VStack(alignment: .leading, spacing: AppTheme.md) {
                labeledField("Amount per check") {
                    TextField("e.g. 2100", text: $payAmountText)
                        .keyboardType(.decimalPad)
                        .font(.app(16, weight: .medium))
                        .appInputText()
                }

                Text("Frequency")
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: AppTheme.sm)], spacing: AppTheme.sm) {
                    ForEach(frequencies, id: \.0) { value, label in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                payFrequency = value
                            }
                        } label: {
                            Text(label)
                                .font(.app(13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(payFrequency == value ? AppTheme.pastelBlue.opacity(0.55) : Color.gray.opacity(0.08))
                                .clipShape(Capsule())
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }

                DatePicker("Next payday", selection: $nextPayDate, displayedComponents: .date)
                    .font(.app(15, weight: .medium))
            }
            .appCard()
        }
        .padding(.horizontal, AppTheme.pagePadding)
        .padding(.top, AppTheme.lg)
        .readableWidth(AdaptiveLayout.formMaxWidth)
    }

    private var categoriesStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.lg) {
            Text("Choose categories")
                .font(.app(22, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, AppTheme.pagePadding)
                .readableWidth(AdaptiveLayout.formMaxWidth)

            ScrollView {
                VStack(spacing: AppTheme.sm) {
                    ForEach(store.state.categories.filter { $0.type == "Expense" }) { category in
                        Toggle(isOn: Binding(
                            get: { selectedCategories.contains(category.name) },
                            set: { enabled in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if enabled { selectedCategories.insert(category.name) }
                                    else { selectedCategories.remove(category.name) }
                                }
                            }
                        )) {
                            HStack {
                                Text(category.name)
                                    .font(.app(15, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Spacer()
                                GroupPill(group: category.group)
                            }
                        }
                        .tint(AppTheme.primaryText)
                        .padding(AppTheme.md)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    addCategoryCard
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.bottom, AppTheme.lg)
                .readableWidth(AdaptiveLayout.formMaxWidth)
            }
        }
        .padding(.top, AppTheme.lg)
    }

    private var addCategoryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.md) {
            Text("Add another category")
                .font(.app(15, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            TextField("Cell phone, pets, childcare...", text: $customCategoryName)
                .font(.app(16, weight: .medium))
                .appInputText()
                .padding(.horizontal, AppTheme.lg)
                .padding(.vertical, AppTheme.md)
                .background(AppTheme.inputFill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Picker("Group", selection: $customCategoryGroup) {
                Text("Needs").tag("Needs")
                Text("Wants").tag("Wants")
                Text("Savings").tag("Savings")
            }
            .pickerStyle(.segmented)

            if !customCategoryMessage.isEmpty {
                Text(customCategoryMessage)
                    .font(.app(13, weight: .medium))
                    .foregroundStyle(AppTheme.expense)
            }

            Button("Add category") {
                addCustomCategory()
            }
            .buttonStyle(PrimaryButtonStyle(disabled: customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            .disabled(customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(AppTheme.md)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.pastelBlue.opacity(0.7), lineWidth: 1)
        )
    }

    private func addCustomCategory() {
        let name = customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if store.state.categories.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            customCategoryMessage = "That category already exists."
            return
        }

        store.addCategory(name: name, group: customCategoryGroup, budget: 0)
        selectedCategories.insert(name)
        customCategoryName = ""
        customCategoryMessage = ""
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {}
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.sm) {
            Text(title)
                .font(.app(13, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
            content()
                .padding(.horizontal, AppTheme.lg)
                .padding(.vertical, AppTheme.md)
                .background(AppTheme.inputFill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func finish() {
        let payAmount = Double(payAmountText.replacingOccurrences(of: ",", with: "")) ?? 0
        let monthlyIncome = monthlyIncomeFromPay(payAmount, payFrequency)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let profile = SetupProfile(
            presetId: "single",
            income: monthlyIncome,
            payAmount: payAmount,
            payFrequency: payFrequency,
            nextPayDate: formatter.string(from: nextPayDate),
            completedAt: ISO8601DateFormatter().string(from: Date()),
            demo: false
        )

        let categories = store.state.categories.map { category -> BudgetCategory in
            guard category.type == "Expense", selectedCategories.contains(category.name) else { return category }
            var updated = category
            updated.budget = suggestedBudget(for: category.name, monthlyIncome: monthlyIncome)
            return updated
        }

        // Setup only saves the profile + category budgets — never invents paycheck transactions.
        store.completeSetup(with: profile, categories: categories)
        dismiss()
    }

    private func monthlyIncomeFromPay(_ amount: Double, _ frequency: String) -> Double {
        switch frequency {
        case "weekly": return amount * 52 / 12
        case "biweekly": return amount * 26 / 12
        case "semimonthly": return amount * 2
        default: return amount
        }
    }

    private func suggestedBudget(for name: String, monthlyIncome: Double) -> Double {
        let weights: [String: Double] = [
            "Housing": 0.34, "Groceries": 0.12, "Transportation": 0.07,
            "Utilities": 0.05, "Insurance": 0.05, "Dining Out": 0.05,
            "Emergency Fund": 0.08, "Subscriptions": 0.02,
        ]
        return (weights[name] ?? 0.03) * monthlyIncome
    }
}
