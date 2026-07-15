import SwiftUI

@main
struct BudgetStudioApp: App {
    @StateObject private var store = BudgetStore()
    @StateObject private var appearanceSettings = AppearanceSettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(appearanceSettings)
                .preferredColorScheme(appearanceSettings.preferredColorScheme)
                .task { await store.bootstrap() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await store.refreshFromCloudIfNeeded() }
                    }
                }
                .onOpenURL { url in
                    store.handleIncomingURL(url)
                }
        }
    }
}
