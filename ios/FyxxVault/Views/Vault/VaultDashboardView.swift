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
    @ObservedObject var subscriptionService: SubscriptionService

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedTab: Int = 1
    @State private var previousTab: Int = 1
    @State private var pendingQuickAction: VaultQuickAction?

    var body: some View {
        Group {
            if sizeClass == .regular {
                // iPad: NavigationSplitView with sidebar
                NavigationSplitView {
                    List(selection: Binding(
                        get: { Optional(selectedTab) },
                        set: { if let v = $0 { selectedTab = v } }
                    )) {
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
                // iPhone: existing tab bar layout with smooth transitions
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
        .onChange(of: selectedTab) { oldValue, _ in
            previousTab = oldValue
        }
    }

    /// Determine slide direction based on tab movement
    private var slidesFromRight: Bool {
        selectedTab > previousTab
    }

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case 0:
                SecurityDashboardView(vaultStore: vaultStore, breachMonitor: breachMonitor) { action in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedTab = 1
                    }
                    pendingQuickAction = action
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                // Subtle parallax offset
                .offset(x: selectedTab == 0 ? 0 : -30)
            case 1:
                VaultListView(vaultStore: vaultStore, subscriptionService: subscriptionService, quickAction: $pendingQuickAction)
                    .transition(.asymmetric(
                        insertion: .move(edge: slidesFromRight ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: slidesFromRight ? .leading : .trailing).combined(with: .opacity)
                    ))
            case 2:
                VaultSettingsView(authManager: authManager, vaultStore: vaultStore, syncService: syncService, maskedEmailService: maskedEmailService, subscriptionService: subscriptionService)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                    // Subtle parallax offset
                    .offset(x: selectedTab == 2 ? 0 : 30)
            default:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: selectedTab)
    }
}
