import SwiftUI

@main
struct BudgetStudioApp: App {
    @StateObject private var store = BudgetStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                // AppTheme is light-only (hardcoded fills); avoid dark-appearance white text on light inputs.
                .preferredColorScheme(.light)
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
