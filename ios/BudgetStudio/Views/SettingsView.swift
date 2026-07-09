import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: BudgetStore
    @Binding var showSetup: Bool

    @State private var payAmountText = ""
    @State private var payFrequency = "biweekly"
    @State private var nextPayDate = Date()

    private let frequencies = [
        ("weekly", "Weekly"),
        ("biweekly", "Biweekly"),
        ("semimonthly", "Twice / mo"),
        ("monthly", "Monthly"),
    ]

    private var activePeriodLabel: String? {
        store.payPeriodSummary?.rangeLabel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    payScheduleCard

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
            .onAppear(perform: loadPayScheduleFromStore)
            .onChange(of: showSetup) { _, isShowing in
                if !isShowing { loadPayScheduleFromStore() }
            }
        }
    }

    private var payScheduleCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppTheme.xs) {
                    Text("Pay schedule")
                        .font(.app(18, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    if let activePeriodLabel {
                        Text(activePeriodLabel)
                            .font(.app(13, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                Spacer()
                Text("💵")
                    .font(.app(22))
                    .frame(width: 40, height: 40)
                    .background(AppTheme.pastelGreen.opacity(0.45), in: Circle())
            }

            labeledField("Amount per check") {
                TextField("e.g. 2100", text: $payAmountText)
                    .keyboardType(.decimalPad)
                    .font(.app(16, weight: .medium))
            }

            VStack(alignment: .leading, spacing: AppTheme.sm) {
                Text("Frequency")
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                FlowFrequencyChips(selection: $payFrequency, options: frequencies)
            }

            DatePicker("Next payday", selection: $nextPayDate, displayedComponents: .date)
                .font(.app(15, weight: .medium))
                .tint(AppTheme.primaryText)

            Button(action: savePaySchedule) {
                Text("Save pay schedule")
                    .font(.app(16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.primaryText)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .appCard()
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

    private func loadPayScheduleFromStore() {
        let profile = store.state.setupProfile
        let amount = profile?.payAmount ?? 0
        payAmountText = amount > 0 ? String(format: amount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", amount) : ""
        payFrequency = profile?.payFrequency ?? "biweekly"
        nextPayDate = parseISODate(profile?.nextPayDate) ?? Date()
    }

    private func savePaySchedule() {
        let amount = Double(payAmountText.replacingOccurrences(of: ",", with: "")) ?? 0
        store.updatePaySchedule(
            payAmount: amount,
            payFrequency: payFrequency,
            nextPayDate: isoString(from: nextPayDate)
        )
    }

    private func parseISODate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func isoString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
}

/// Wrapping chip row for pay frequency (fits iPhone + iPad).
private struct FlowFrequencyChips: View {
    @Binding var selection: String
    let options: [(String, String)]

    var body: some View {
        // LazyVGrid keeps chips tidy without a custom flow layout.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: AppTheme.sm)], spacing: AppTheme.sm) {
            ForEach(options, id: \.0) { value, label in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = value
                    }
                } label: {
                    Text(label)
                        .font(.app(13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection == value ? AppTheme.pastelBlue.opacity(0.55) : Color.gray.opacity(0.08))
                        .clipShape(Capsule())
                        .foregroundStyle(AppTheme.primaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
