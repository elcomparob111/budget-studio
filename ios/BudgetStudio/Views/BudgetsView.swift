import SwiftUI

struct BudgetsView: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var newCategoryName = ""
    @State private var newCategoryGroup = "Needs"
    @State private var newCategoryBudget = ""
    /// Draft text while typing so each keystroke does not hit cloud sync.
    @State private var budgetDrafts: [String: String] = [:]
    @State private var budgetCommitTask: Task<Void, Never>?
    @State private var editingCategory: BudgetCategory?
    @FocusState private var focusedBudgetName: String?
    @FocusState private var newBudgetFocused: Bool

    private var expenseCategories: [BudgetCategory] {
        store.state.categories.filter { $0.type == "Expense" }
    }

    private var usesSheetEditor: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                        categoryBudgetsCard
                        addCategoryCard
                    }
                    .padding(.horizontal, AppTheme.pagePadding)
                    .padding(.top, AppTheme.lg)
                    .padding(.bottom, AppTheme.xxl)
                    .readableWidth(AdaptiveLayout.formMaxWidth)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(AppTheme.background.ignoresSafeArea())
                .navigationTitle("Budgets")
                .decimalPadDoneToolbar()
                .onChange(of: focusedBudgetName) { _, name in
                    guard let name else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(budgetRowID(name), anchor: .center)
                    }
                }
                .onChange(of: newBudgetFocused) { _, focused in
                    guard focused else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo("add-category", anchor: .bottom)
                    }
                }
                .onDisappear { commitAllBudgetDrafts() }
                .sheet(item: $editingCategory) { category in
                    BudgetAmountEditorSheet(
                        categoryName: category.name,
                        group: category.group,
                        amountText: budgetDisplayValue(for: category.name)
                    ) { newValue in
                        budgetDrafts[category.name] = newValue
                        commitBudgetDraft(for: category.name)
                    }
                    .appSheetChrome(detents: [.height(280), .medium])
                }
            }
        }
    }

    private var categoryBudgetsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.md) {
            Text("Category budgets")
                .font(.app(18, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            if expenseCategories.isEmpty {
                Text("No expense categories yet. Add one below.")
                    .font(.app(14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.vertical, AppTheme.sm)
            } else {
                ForEach(expenseCategories) { category in
                    HStack {
                        VStack(alignment: .leading, spacing: AppTheme.xs) {
                            Text(category.name)
                                .font(.app(15, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)
                            GroupPill(group: category.group)
                        }
                        Spacer()
                        budgetAmountControl(for: category)
                    }
                    .id(budgetRowID(category.name))
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func budgetAmountControl(for category: BudgetCategory) -> some View {
        if usesSheetEditor {
            Button {
                editingCategory = category
            } label: {
                Text(budgetDisplayValue(for: category.name).isEmpty
                      ? "0"
                      : budgetDisplayValue(for: category.name))
                    .font(.app(16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 96, alignment: .trailing)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.inputFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(category.name) budget")
            .accessibilityHint("Opens amount editor")
        } else {
            TextField(
                "0",
                text: budgetTextBinding(for: category.name),
                prompt: Text("0")
            )
            .font(.app(16, weight: .semibold))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .appInputText()
            .focused($focusedBudgetName, equals: category.name)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 96)
            .background(AppTheme.inputFill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onSubmit { commitBudgetDraft(for: category.name) }
        }
    }

    private var addCategoryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.md) {
            Text("Add category")
                .font(.app(18, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            TextField("New category", text: $newCategoryName)
                .font(.app(16, weight: .medium))
                .appInputText()
                .padding(.horizontal, AppTheme.lg)
                .padding(.vertical, AppTheme.md)
                .background(AppTheme.inputFill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Picker("Group", selection: $newCategoryGroup) {
                Text("Needs").tag("Needs")
                Text("Wants").tag("Wants")
                Text("Savings").tag("Savings")
            }
            .pickerStyle(.segmented)

            TextField("Monthly budget", text: $newCategoryBudget)
                .font(.app(16, weight: .medium))
                .keyboardType(.decimalPad)
                .appInputText()
                .focused($newBudgetFocused)
                .padding(.horizontal, AppTheme.lg)
                .padding(.vertical, AppTheme.md)
                .background(AppTheme.inputFill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button("Add category") {
                store.addCategory(
                    name: newCategoryName,
                    group: newCategoryGroup,
                    budget: Double(newCategoryBudget) ?? 0
                )
                newCategoryName = ""
                newCategoryBudget = ""
                newBudgetFocused = false
            }
            .buttonStyle(PrimaryButtonStyle(disabled: newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .appCard()
        .id("add-category")
    }

    private func budgetRowID(_ name: String) -> String {
        "budget-\(name)"
    }

    private func budgetDisplayValue(for name: String) -> String {
        if let draft = budgetDrafts[name] { return draft }
        let value = store.state.categories.first(where: { $0.name == name })?.budget ?? 0
        if value == 0 { return "" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(value)
    }

    private func budgetTextBinding(for name: String) -> Binding<String> {
        Binding(
            get: { budgetDisplayValue(for: name) },
            set: { newValue in
                budgetDrafts[name] = newValue
                scheduleBudgetCommit()
            }
        )
    }

    private func scheduleBudgetCommit() {
        budgetCommitTask?.cancel()
        budgetCommitTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(800))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            commitAllBudgetDrafts()
        }
    }

    private func commitBudgetDraft(for name: String) {
        guard let draft = budgetDrafts[name] else { return }
        let parsed = Double(draft.replacingOccurrences(of: ",", with: "")) ?? 0
        store.updateCategoryBudget(name: name, budget: parsed)
        budgetDrafts[name] = nil
    }

    private func commitAllBudgetDrafts() {
        budgetCommitTask?.cancel()
        let names = Array(budgetDrafts.keys)
        for name in names {
            commitBudgetDraft(for: name)
        }
    }
}

private struct BudgetAmountEditorSheet: View {
    let categoryName: String
    let group: String
    @State private var amountText: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool

    init(categoryName: String, group: String, amountText: String, onSave: @escaping (String) -> Void) {
        self.categoryName = categoryName
        self.group = group
        self._amountText = State(initialValue: amountText)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.lg) {
                HStack(spacing: AppTheme.md) {
                    VStack(alignment: .leading, spacing: AppTheme.xs) {
                        Text(categoryName)
                            .font(.app(20, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                        GroupPill(group: group)
                    }
                    Spacer()
                }

                Text("Monthly budget")
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)

                TextField("0", text: $amountText, prompt: Text("0"))
                    .font(.app(28, weight: .bold))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .appInputText()
                    .focused($amountFocused)
                    .padding(.horizontal, AppTheme.lg)
                    .padding(.vertical, AppTheme.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.inputFill)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button("Save") {
                    onSave(amountText)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.top, AppTheme.lg)
            .padding(.bottom, AppTheme.xl)
            .readableWidth(AdaptiveLayout.formMaxWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Edit budget")
            .navigationBarTitleDisplayMode(.inline)
            .decimalPadDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    amountFocused = true
                }
            }
        }
    }
}
