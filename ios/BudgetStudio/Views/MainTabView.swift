import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var store: BudgetStore
    @State private var selectedTab = 0
    @State private var showAddTransaction = false
    @State private var preferScanOnAdd = false
    @State private var showSetup = false

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewView(
                showSetup: $showSetup,
                showAddTransaction: $showAddTransaction,
                onAddManually: { openAdd(preferScan: false) },
                onScanReceipt: { openAdd(preferScan: true) }
            )
                .tabItem {
                    Label("Overview", systemImage: "chart.pie.fill")
                }
                .tag(0)

            TransactionsView(
                showAddTransaction: $showAddTransaction,
                onAddManually: { openAdd(preferScan: false) },
                onScanReceipt: { openAdd(preferScan: true) }
            )
                .tabItem {
                    Label("Activity", systemImage: "list.bullet")
                }
                .tag(1)

            BudgetsView()
                .tabItem {
                    Label("Budgets", systemImage: "chart.bar.fill")
                }
                .tag(2)

            SettingsView(showSetup: $showSetup)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(AppTheme.primaryText)
        .sheet(isPresented: $showAddTransaction, onDismiss: {
            preferScanOnAdd = false
        }) {
            AddTransactionSheet(startWithScan: preferScanOnAdd)
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
            consumePendingQuickAdd()
        }
        .onChange(of: store.state.setupComplete) { _, complete in
            if complete { showSetup = false }
        }
        .onChange(of: store.pendingQuickAdd) { _, pending in
            if pending { consumePendingQuickAdd() }
        }
        .onChange(of: store.isUnlocked) { _, unlocked in
            if unlocked { consumePendingQuickAdd() }
        }
    }

    private func openAdd(preferScan: Bool) {
        preferScanOnAdd = preferScan
        showAddTransaction = true
    }

    private func consumePendingQuickAdd() {
        guard store.pendingQuickAdd, store.isAuthenticated, store.isUnlocked else { return }
        store.pendingQuickAdd = false
        openAdd(preferScan: false)
    }

    private func presentSetupIfNeeded() {
        guard store.isAuthenticated, !store.state.setupComplete else { return }
        showSetup = true
    }
}
