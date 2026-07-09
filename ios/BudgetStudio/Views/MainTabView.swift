import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var store: BudgetStore
    @State private var selectedTab = 0
    @State private var showAddTransaction = false
    @State private var showSetup = false

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewView(showSetup: $showSetup, showAddTransaction: $showAddTransaction)
                .tabItem {
                    Label("Overview", systemImage: "chart.pie.fill")
                }
                .tag(0)

            TransactionsView(showAddTransaction: $showAddTransaction)
                .tabItem {
                    Label("Activity", systemImage: "list.bullet")
                }
                .tag(1)

            SettingsView(showSetup: $showSetup)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(AppTheme.primaryText)
        .sheet(isPresented: $showAddTransaction) {
            AddTransactionSheet()
                .appSheetChrome(detents: [.medium, .large])
        }
        .sheet(isPresented: $showSetup, onDismiss: {
            // If the sheet was dismissed without finishing, still persist completion
            // so setup does not reopen on every launch.
            store.markSetupCompleteIfNeeded()
        }) {
            SetupWizardView()
                .appSheetChrome()
        }
        .onAppear {
            presentSetupIfNeeded()
        }
        .onChange(of: store.state.setupComplete) { _, complete in
            if complete { showSetup = false }
        }
    }

    private func presentSetupIfNeeded() {
        guard store.isAuthenticated, !store.state.setupComplete else { return }
        showSetup = true
    }
}
