import SwiftUI

@main
struct BudgetStudioApp: App {
    @StateObject private var store = BudgetStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task { await store.bootstrap() }
        }
    }
}
