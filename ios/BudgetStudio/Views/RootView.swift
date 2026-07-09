import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: BudgetStore

    var body: some View {
        Group {
            if store.isAuthenticated && store.isUnlocked {
                MainTabView()
            } else if store.canUseFaceID || (store.isAuthenticated && !store.isUnlocked) {
                FaceIDLockView()
            } else {
                AuthView()
            }
        }
        .overlay(alignment: .top) {
            if let message = store.toastMessage {
                Text(message)
                    .font(.app(14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.primaryText.opacity(0.92), in: Capsule())
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.toastMessage = nil
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.isAuthenticated)
        .animation(.easeInOut(duration: 0.2), value: store.isUnlocked)
        .animation(.easeInOut(duration: 0.2), value: store.toastMessage)
    }
}

struct FaceIDLockView: View {
    @EnvironmentObject private var store: BudgetStore
    @State private var showPasswordLogin = false

    var body: some View {
        VStack(spacing: AppTheme.xl) {
            Spacer()

            VStack(spacing: AppTheme.md) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)

                Text("Budget Studio")
                    .font(.app(12, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Text("Welcome back")
                    .font(.app(28, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                if !store.userName.isEmpty {
                    Text(store.userName)
                        .font(.app(16, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            VStack(spacing: AppTheme.md) {
                Button {
                    Task { await store.unlockWithFaceID() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Unlock with \(store.biometryLabel)")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(disabled: store.isLoading))
                .disabled(store.isLoading)

                if let error = store.authError {
                    Text(error)
                        .font(.app(13, weight: .medium))
                        .foregroundStyle(AppTheme.expense)
                        .multilineTextAlignment(.center)
                }

                Button("Use password instead") {
                    showPasswordLogin = true
                }
                .font(.app(14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .readableWidth(AdaptiveLayout.lockMaxWidth)

            Spacer()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .task {
            await store.unlockWithFaceID()
        }
        .sheet(isPresented: $showPasswordLogin) {
            AuthView()
                .environmentObject(store)
                .appSheetChrome()
        }
    }
}
