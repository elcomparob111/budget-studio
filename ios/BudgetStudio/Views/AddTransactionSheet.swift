import SwiftUI
import PhotosUI
import UIKit

struct AddTransactionSheet: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.dismiss) private var dismiss

    var existing: BudgetTransaction?
    var prefill: TransactionPrefill?
    /// When true (new transactions only), open the camera/library flow on appear.
    var startWithScan = false

    @State private var date = Date()
    @State private var type = "Expense"
    @State private var category = ""
    @State private var account = BudgetDefaults.accounts[0]
    @State private var description = ""
    @State private var amount = ""
    @FocusState private var amountFocused: Bool

    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var isScanning = false
    @State private var scanBanner: String?
    @State private var scanError: String?
    @State private var didAutoPresentScan = false

    private var categories: [BudgetCategory] {
        store.state.categories.filter { $0.type == type }
    }

    private var canSave: Bool {
        Double(amount) != nil && !category.isEmpty
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.lg) {
                        if existing == nil {
                            scanReceiptSection
                        }

                        if let scanBanner {
                            Text(scanBanner)
                                .font(.app(13, weight: .medium))
                                .foregroundStyle(AppTheme.secondaryText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.pastelGreen.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        if let scanError {
                            Text(scanError)
                                .font(.app(13, weight: .medium))
                                .foregroundStyle(AppTheme.expense)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.pastelPink.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

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
                                .focused($amountFocused)
                        }
                        .id("amount-field")

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
                .scrollDismissesKeyboard(.interactively)
                .background(AppTheme.background.ignoresSafeArea())
                .navigationTitle(existing == nil ? "New transaction" : "Edit transaction")
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
                    populate()
                    presentScanIfRequested()
                }
                .onChange(of: type) { _, _ in
                    if !categories.contains(where: { $0.name == category }) {
                        category = categories.first?.name ?? ""
                    }
                }
                .onChange(of: amountFocused) { _, focused in
                    guard focused else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo("amount-field", anchor: .center)
                    }
                }
                .onChange(of: photoItem) { _, item in
                    guard let item else { return }
                    Task { await loadAndScan(item: item) }
                }
                .onChange(of: cameraImage) { _, image in
                    guard let image else { return }
                    Task { await scan(image: image) }
                }
                .fullScreenCover(isPresented: $showCamera) {
                    CameraImagePicker(image: $cameraImage)
                        .ignoresSafeArea()
                }
                .overlay {
                    if isScanning {
                        ZStack {
                            Color.black.opacity(0.2).ignoresSafeArea()
                            VStack(spacing: AppTheme.md) {
                                ProgressView()
                                    .tint(AppTheme.primaryText)
                                Text("Reading receipt…")
                                    .font(.app(15, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                            }
                            .padding(AppTheme.xl)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                        }
                    }
                }
            }
        }
    }

    private var scanReceiptSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.sm) {
            Text("Scan receipt")
                .font(.app(13, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: AppTheme.sm) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                        .font(.app(14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.pastelBlue.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isScanning)

                if cameraAvailable {
                    Button {
                        cameraImage = nil
                        showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera.fill")
                            .font(.app(14, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.pastelPurple.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isScanning)
                }
            }

            Text("We’ll fill what we can — review before saving.")
                .font(.app(12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func presentScanIfRequested() {
        guard startWithScan, existing == nil, !didAutoPresentScan else { return }
        didAutoPresentScan = true
        // Brief delay so the sheet finishes presenting before the camera covers it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if cameraAvailable {
                cameraImage = nil
                showCamera = true
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
        } else if let prefill {
            applyPrefill(prefill, announce: false)
        } else {
            category = categories.first?.name ?? ""
        }
    }

    private func applyPrefill(_ prefill: TransactionPrefill, announce: Bool) {
        if let d = prefill.date { date = d }
        if let t = prefill.type { type = t }
        if let desc = prefill.description, !desc.isEmpty { description = desc }
        if let amt = prefill.amount, !amt.isEmpty { amount = amt }
        if let acct = prefill.account, BudgetDefaults.accounts.contains(acct) {
            account = acct
        }

        // Resolve category after type is set
        if let cat = prefill.category,
           store.state.categories.contains(where: { $0.name == cat && $0.type == type }) {
            category = cat
        } else if !categories.contains(where: { $0.name == category }) {
            category = categories.first?.name ?? ""
        }

        if announce {
            var parts: [String] = []
            if prefill.amount != nil { parts.append("amount") }
            if prefill.description != nil { parts.append("description") }
            if prefill.date != nil { parts.append("date") }
            if let t = prefill.type { parts.append(t.lowercased()) }
            scanBanner = parts.isEmpty
                ? "Scanned — edit anything that looks off."
                : "Filled \(parts.joined(separator: ", ")). Confirm before saving."
            scanError = nil
        }
    }

    private func loadAndScan(item: PhotosPickerItem) async {
        isScanning = true
        scanError = nil
        scanBanner = nil
        defer {
            isScanning = false
            photoItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                scanError = "Could not load that photo."
                return
            }
            await scan(image: image)
        } catch {
            scanError = error.localizedDescription
        }
    }

    private func scan(image: UIImage) async {
        isScanning = true
        scanError = nil
        defer { isScanning = false }

        do {
            let result = try await ReceiptOCRService.recognize(from: image)
            applyPrefill(result.asPrefill, announce: true)
        } catch {
            scanError = error.localizedDescription
            scanBanner = nil
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
