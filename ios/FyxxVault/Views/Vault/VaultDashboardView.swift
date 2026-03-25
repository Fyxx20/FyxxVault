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

    @State private var selectedTab: Int = 1
    @State private var pendingQuickAction: VaultQuickAction?

    var body: some View {
        ZStack {
            Group {
                switch selectedTab {
                case 0:
                    SecurityDashboardView(vaultStore: vaultStore) { action in
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
                    VaultSettingsView(authManager: authManager, vaultStore: vaultStore)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                default:
                    EmptyView()
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FVTabBar(selectedTab: $selectedTab)
        }
        .background(FVAnimatedBackground())
        .tint(FVColor.cyan)
    }
}
