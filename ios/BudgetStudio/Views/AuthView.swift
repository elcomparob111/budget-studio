import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var store: BudgetStore
    @State private var mode: AuthMode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    enum AuthMode {
        case signIn, signUp
    }

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6 && (mode == .signIn || !name.isEmpty)
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: AppTheme.xl) {
                    VStack(spacing: AppTheme.md) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)

                        Text("Budget Studio")
                            .font(.app(12, weight: .bold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .textCase(.uppercase)
                            .tracking(1.2)

                        Text(mode == .signUp ? "Create your account" : "Welcome back")
                            .font(.app(28, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text("Sign in and your budget follows you on every device — private to your account only.")
                            .font(.app(16, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, max(AppTheme.xxl, (geo.size.height - 520) * 0.18))

                    VStack(spacing: AppTheme.md) {
                        if mode == .signUp {
                            AuthField(title: "Your name", text: $name, placeholder: "Rob, Mom, Alex...")
                        }
                        AuthField(title: "Email", text: $email, placeholder: "you@example.com", keyboard: .emailAddress)
                        AuthField(title: "Password", text: $password, placeholder: "At least 6 characters", isSecure: true)

                        if let error = store.authError {
                            Text(error)
                                .font(.app(13, weight: .medium))
                                .foregroundStyle(AppTheme.expense)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task {
                                if mode == .signUp {
                                    await store.signUp(name: name, email: email, password: password)
                                } else {
                                    await store.signIn(email: email, password: password)
                                }
                            }
                        } label: {
                            Group {
                                if store.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(mode == .signUp ? "Create account" : "Sign in")
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(disabled: !canSubmit || store.isLoading))
                        .disabled(!canSubmit || store.isLoading)

                        if mode == .signIn && store.canUseFaceID {
                            Button {
                                Task { await store.unlockWithFaceID() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "faceid")
                                    Text("Sign in with \(store.biometryLabel)")
                                }
                                .font(.app(15, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.inputFill)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .disabled(store.isLoading)
                        }

                        if mode == .signIn {
                            Button("Forgot password?") {
                                Task { await store.resetPassword(email: email) }
                            }
                            .font(.app(14, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .disabled(email.isEmpty || store.isLoading)
                        }

                        Button(mode == .signUp ? "Already have an account? Sign in" : "New here? Create an account") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mode = mode == .signUp ? .signIn : .signUp
                                store.authError = nil
                            }
                        }
                        .font(.app(14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    }
                    .appCard()
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.bottom, AppTheme.xxl)
                .readableWidth(AdaptiveLayout.authMaxWidth)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}

private struct AuthField: View {
    let title: String
    @Binding var text: String
    var placeholder = ""
    var keyboard: UIKeyboardType = .default
    var isSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.sm) {
            Text(title)
                .font(.app(13, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(.app(16, weight: .medium))
            .appInputText()
            .padding(.horizontal, AppTheme.lg)
            .padding(.vertical, AppTheme.md)
            .background(AppTheme.inputFill)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
