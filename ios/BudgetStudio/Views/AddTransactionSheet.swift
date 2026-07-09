import SwiftUI

struct AddTransactionSheet: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.dismiss) private var dismiss

    var existing: BudgetTransaction?

    @State private var date = Date()
    @State private var type = "Expense"
    @State private var category = ""
    @State private var account = BudgetDefaults.accounts[0]
    @State private var description = ""
    @State private var amount = ""

    private var categories: [BudgetCategory] {
        store.state.categories.filter { $0.type == type }
    }

    private var canSave: Bool {
        Double(amount) != nil && !category.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.lg) {
                    typeChips

                    fieldLabel("Date") {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                    }

                    fieldLabel("Category") {
                        Picker("", selection: $category) {
                            ForEach(categories, id: \.id) { item in
                                Text(item.name).tag(item.name)
                            }
                        }
                        .labelsHidden()
                    }

                    fieldLabel("Account") {
                        Picker("", selection: $account) {
                            ForEach(BudgetDefaults.accounts, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }

                    fieldLabel("Description") {
                        TextField("What was this for?", text: $description)
                            .font(.app(16, weight: .medium))
                            .appInputText()
                    }

                    fieldLabel("Amount") {
                        TextField("0.00", text: $amount)
                            .font(.app(16, weight: .medium))
                            .keyboardType(.decimalPad)
                            .appInputText()
                    }

                    Button(existing == nil ? "Add transaction" : "Save changes") {
                        save()
                    }
                    .buttonStyle(PrimaryButtonStyle(disabled: !canSave))
                    .disabled(!canSave)
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, AppTheme.lg)
                .padding(.bottom, AppTheme.xl)
                .readableWidth(AdaptiveLayout.formMaxWidth)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(existing == nil ? "New transaction" : "Edit transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
            .onAppear(perform: populate)
            .onChange(of: type) { _, _ in
                if !categories.contains(where: { $0.name == category }) {
                    category = categories.first?.name ?? ""
                }
            }
        }
    }

    private var typeChips: some View {
        HStack(spacing: AppTheme.sm) {
            ForEach(["Expense", "Income"], id: \.self) { value in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        type = value
                    }
                } label: {
                    Text(value)
                        .font(.app(13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(type == value ? AppTheme.pastelBlue.opacity(0.55) : Color.gray.opacity(0.08))
                        .clipShape(Capsule())
                        .foregroundStyle(AppTheme.primaryText)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func fieldLabel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.sm) {
            Text(title)
                .font(.app(13, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
            content()
                .padding(.horizontal, AppTheme.lg)
                .padding(.vertical, AppTheme.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.inputFill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func populate() {
        if let existing {
            date = parseDate(existing.date) ?? Date()
            type = existing.type
            category = existing.category
            account = existing.account
            description = existing.description
            amount = String(existing.amount)
        } else {
            category = categories.first?.name ?? ""
        }
    }

    private func save() {
        guard let value = Double(amount) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let payload = BudgetTransaction(
            id: existing?.id ?? UUID().uuidString,
            date: formatter.string(from: date),
            type: type,
            category: category,
            description: description,
            account: account,
            amount: value
        )
        if existing == nil {
            store.addTransaction(payload)
        } else {
            store.updateTransaction(payload)
        }
        dismiss()
    }

    private func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
