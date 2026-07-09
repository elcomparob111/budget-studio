import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: BudgetStore
    @Binding var showSetup: Bool

    @State private var newCategoryName = ""
    @State private var newCategoryGroup = "Needs"
    @State private var newCategoryBudget = ""
    /// Draft text while typing so each keystroke does not hit cloud sync.
    @State private var budgetDrafts: [String: String] = [:]
    @State private var budgetCommitTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    VStack(spacing: AppTheme.sm) {
                        settingsButton(title: "Open setup wizard", emoji: "🪄") { showSetup = true }
                        settingsButton(title: "Load demo budget", emoji: "🧪") { store.loadDemo() }
                    }

                    if BiometricAuth.isAvailable {
                        VStack(alignment: .leading, spacing: AppTheme.md) {
                            HStack(spacing: AppTheme.md) {
                                Image(systemName: "faceid")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .frame(width: 40, height: 40)
                                    .background(AppTheme.pastelBlue.opacity(0.45), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock with \(store.biometryLabel)")
                                        .font(.app(16, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryText)
                                    Text(store.faceIDEnabled
                                          ? "On — next launch asks for \(store.biometryLabel)"
                                          : "Sign in with password once to enable")
                                        .font(.app(12, weight: .medium))
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { store.faceIDEnabled },
                                    set: { enabled in
                                        if !enabled {
                                            store.disableFaceID()
                                        }
                                    }
                                ))
                                .labelsHidden()
                                .tint(AppTheme.primaryText)
                                .disabled(!store.faceIDEnabled)
                            }
                        }
                        .appCard()
                    }

                    VStack(alignment: .leading, spacing: AppTheme.md) {
                        Text("Monthly category budgets")
                            .font(.app(18, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)

                        ForEach(store.state.categories.filter { $0.type == "Expense" }) { category in
                            HStack {
                                VStack(alignment: .leading, spacing: AppTheme.xs) {
                                    Text(category.name)
                                        .font(.app(15, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryText)
                                    GroupPill(group: category.group)
                                }
                                Spacer()
                                TextField(
                                    "0",
                                    text: budgetTextBinding(for: category.name),
                                    prompt: Text("0")
                                )
                                    .font(.app(16, weight: .semibold))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .appInputText()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(width: 96)
                                    .background(AppTheme.inputFill)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .onSubmit { commitBudgetDraft(for: category.name) }
                            }
                        }
                    }
                    .appCard()

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
                        }
                        .buttonStyle(PrimaryButtonStyle(disabled: newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .appCard()

                    Button {
                        Task { await store.signOut() }
                    } label: {
                        Text("Sign out")
                            .font(.app(16, weight: .bold))
                            .foregroundStyle(AppTheme.expense)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.pastelPink.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, AppTheme.lg)
                .padding(.bottom, AppTheme.xxl)
                .readableWidth(AdaptiveLayout.formMaxWidth)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .onDisappear { commitAllBudgetDrafts() }
        }
    }

    private func settingsButton(title: String, emoji: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.md) {
                Text(emoji)
                    .font(.app(22))
                    .frame(width: 40, height: 40)
                    .background(AppTheme.pastelPurple.opacity(0.45), in: Circle())
                Text(title)
                    .font(.app(16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .appCard()
        }
        .buttonStyle(.plain)
    }

    private func budgetTextBinding(for name: String) -> Binding<String> {
        Binding(
            get: {
                if let draft = budgetDrafts[name] { return draft }
                let value = store.state.categories.first(where: { $0.name == name })?.budget ?? 0
                if value == 0 { return "" }
                return value.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(value))
                    : String(value)
            },
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
