import SwiftUI

@main
struct BudgetStudioApp: App {
    @StateObject private var store = BudgetStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                // AppTheme is light-only (hardcoded fills); avoid dark-appearance white text on light inputs.
                .preferredColorScheme(.light)
                .task { await store.bootstrap() }
                .onOpenURL { url in
                    store.handleIncomingURL(url)
                }
        }
    }
}
