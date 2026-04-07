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
    @ObservedObject var mailService: FyxxMailService
    @ObservedObject var announcementsService: AnnouncementsService
    @ObservedObject var supportService: SupportService

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedTab: Int = 2  // Start on Vault tab (center)
    @State private var previousTab: Int = 2
    @State private var pendingQuickAction: VaultQuickAction?
    @State private var vaultPollTask: Task<Void, Never>?

    var body: some View {
        Group {
            if sizeClass == .regular {
                // iPad: NavigationSplitView with sidebar
                NavigationSplitView {
                    List(selection: Binding(
                        get: { Optional(selectedTab) },
                        set: { if let v = $0 { selectedTab = v } }
                    )) {
                        Label("Sécurité", systemImage: "shield.checkered").tag(0)
                        Label("Emails", systemImage: "envelope.fill").tag(1)
                        Label("Coffre", systemImage: "lock.rectangle.stack").tag(2)
                        Label("Identité", systemImage: "person.text.rectangle.fill").tag(3)
                        Label("Réglages", systemImage: "gearshape").tag(4)
                    }
                    .listStyle(.sidebar)
                    .navigationTitle("FyxxVault")
                } detail: {
                    tabContent
                }
            } else {
                // iPhone: tab bar layout with smooth transitions
                ZStack(alignment: .bottomTrailing) {
                    tabContent

                    // Support chat floating widget (above tab bar)
                    SupportChatOverlay(
                        supportService: supportService,
                        userEmail: authManager.currentEmail
                    )
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    FVTabBar(
                        selectedTab: $selectedTab,
                        mailUnread: mailService.unreadCount,
                        announcementUnread: announcementsService.unreadCount
                    )
                }
            }
        }
        .background(FVAnimatedBackground())
        .tint(FVColor.cyan)
        .onChange(of: selectedTab) { oldValue, newValue in
            previousTab = oldValue
            updatePolling(tab: newValue)
        }
        .onAppear { updatePolling(tab: selectedTab) }
        .onDisappear { stopAllPolling() }
    }

    private func updatePolling(tab: Int) {
        // Stop non-vault polling
        mailService.stopPolling()
        supportService.stopTicketListPolling()

        // Start polling for active tab
        switch tab {
        case 1: // Mails — poll every 5s
            mailService.startPolling()
        default:
            break
        }

        // Vault sync: 5s on vault tab, 10s on others
        startVaultPolling(interval: tab == 2 ? 5 : 10)

        // Announcements always poll (for badge count)
        announcementsService.startPolling()
    }

    private func startVaultPolling(interval: UInt64) {
        vaultPollTask?.cancel()
        guard syncService.isCloudAuthenticated else { return }
        let vs = vaultStore
        let ss = syncService
        let sub = subscriptionService
        vaultPollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval * 1_000_000_000)
                guard !Task.isCancelled else { break }
                do {
                    let merged = try await ss.sync(localEntries: vs.entries)
                    // SAFETY: never replace with empty if we had entries
                    if !merged.isEmpty {
                        await MainActor.run {
                            vs.replaceEntries(merged)
                        }
                    } else {
                        print("[VaultPoll] Skipped empty merge — kept \(vs.entries.count) local entries")
                    }
                } catch {
                    print("[VaultPoll] sync error: \(error)")
                }
                // Refresh Pro status
                await ss.refreshCloudProStatus()
                await MainActor.run {
                    sub.setCloudProStatus(ss.cloudIsProUser)
                }
            }
        }
    }

    private func stopAllPolling() {
        mailService.stopPolling()
        announcementsService.stopPolling()
        supportService.stopTicketListPolling()
        vaultPollTask?.cancel()
        vaultPollTask = nil
    }

    private var slidesFromRight: Bool { selectedTab > previousTab }

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case 0:
                SecurityDashboardView(
                    vaultStore: vaultStore,
                    breachMonitor: breachMonitor,
                    subscriptionService: subscriptionService
                ) { action in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedTab = 2 }
                    pendingQuickAction = action
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .offset(x: selectedTab == 0 ? 0 : -30)

            case 1:
                FyxxMailView(mailService: mailService, subscriptionService: subscriptionService)
                    .transition(.asymmetric(
                        insertion: .move(edge: slidesFromRight ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: slidesFromRight ? .leading : .trailing).combined(with: .opacity)
                    ))

            case 2:
                VaultListView(
                    vaultStore: vaultStore,
                    syncService: syncService,
                    subscriptionService: subscriptionService,
                    quickAction: $pendingQuickAction
                )
                .transition(.asymmetric(
                    insertion: .move(edge: slidesFromRight ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: slidesFromRight ? .leading : .trailing).combined(with: .opacity)
                ))

            case 3:
                IdentityGeneratorView()
                    .transition(.asymmetric(
                        insertion: .move(edge: slidesFromRight ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: slidesFromRight ? .leading : .trailing).combined(with: .opacity)
                    ))

            case 4:
                VaultSettingsView(
                    authManager: authManager,
                    vaultStore: vaultStore,
                    syncService: syncService,
                    maskedEmailService: maskedEmailService,
                    subscriptionService: subscriptionService,
                    announcementsService: announcementsService
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
                .offset(x: selectedTab == 4 ? 0 : 30)

            default:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: selectedTab)
    }
}
