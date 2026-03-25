import SwiftUI

enum VaultQuickAction {
    case weakPasswords
    case reusedPasswords
    case missingMFA
    case expiredPasswords
}

struct VaultDashboardView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var vaultStore: VaultStore
    @ObservedObject var syncService: SyncService
    @ObservedObject var breachMonitor: BreachMonitorService
    @ObservedObject var maskedEmailService: MaskedEmailService

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedTab: Int = 1
    @State private var pendingQuickAction: VaultQuickAction?

    var body: some View {
        Group {
            if sizeClass == .regular {
                // iPad: NavigationSplitView with sidebar
                NavigationSplitView {
                    List(selection: $selectedTab) {
                        Label(String(localized: "tab.security"), systemImage: "shield.checkered")
                            .tag(0)
                        Label(String(localized: "tab.vault"), systemImage: "lock.rectangle.stack")
                            .tag(1)
                        Label(String(localized: "tab.settings"), systemImage: "gearshape")
                            .tag(2)
                    }
                    .listStyle(.sidebar)
                    .navigationTitle("FyxxVault")
                } detail: {
                    tabContent
                }
            } else {
                // iPhone: existing tab bar layout
                ZStack {
                    tabContent
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    FVTabBar(selectedTab: $selectedTab)
                }
            }
        }
        .background(FVAnimatedBackground())
        .tint(FVColor.cyan)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            SecurityDashboardView(vaultStore: vaultStore, breachMonitor: breachMonitor) { action in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    selectedTab = 1
                }
                pendingQuickAction = action
            }
            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
        case 1:
            VaultListView(vaultStore: vaultStore, quickAction: $pendingQuickAction)
                .transition(.opacity)
        case 2:
            VaultSettingsView(authManager: authManager, vaultStore: vaultStore, syncService: syncService, maskedEmailService: maskedEmailService)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        default:
            EmptyView()
        }
    }
}
