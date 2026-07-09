import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: BudgetStore
    @Binding var showSetup: Bool

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
}
