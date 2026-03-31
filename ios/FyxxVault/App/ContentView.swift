import SwiftUI
import Combine

// MARK: - Root View

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @StateObject private var vaultStore = VaultStore()
    @StateObject private var appLock = AppLockManager()
    @StateObject private var syncService = SyncService()
    @StateObject private var breachMonitor = BreachMonitorService()
    @StateObject private var maskedEmailService = MaskedEmailService()
    @StateObject private var subscriptionService = SubscriptionService()
    @StateObject private var mailService = FyxxMailService()
    @StateObject private var announcementsService = AnnouncementsService()
    @StateObject private var supportService = SupportService()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isSyncing = false

    var body: some View {
        ZStack {
            FVAnimatedBackground()

            Group {
                switch authManager.phase {
                case .auth:
                    AuthView(authManager: authManager)
                case .onboarding:
                    OnboardingView(authManager: authManager)
                case .vault:
                    if appLock.isLocked {
                        VaultLockView(appLock: appLock, authManager: authManager)
                    } else {
                        VaultDashboardView(authManager: authManager, vaultStore: vaultStore, syncService: syncService, breachMonitor: breachMonitor, maskedEmailService: maskedEmailService, subscriptionService: subscriptionService, mailService: mailService, announcementsService: announcementsService, supportService: supportService)
                    }
                }
            }
            .padding(.horizontal, authManager.phase == .vault ? 10 : 20)
            .padding(.vertical, authManager.phase == .vault ? 0 : 28)

            // Screenshot detection overlay
            if appLock.screenshotDetected {
                Color.black.opacity(0.92)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(FVColor.danger)
                            Text(String(localized: "screenshot.detected"))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(String(localized: "screenshot.vaultLocked"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            appLock.configureFromSettings()
            authManager.setSyncService(syncService)
            mailService.syncService = syncService
            supportService.syncService = syncService
            announcementsService.syncService = syncService
            if authManager.phase == .vault {
                appLock.activateForVaultEntry()
            }
        }
        .task(id: authManager.phase) {
            guard authManager.phase == .vault else { return }
            if breachMonitor.shouldAutoScan() && subscriptionService.isProUser {
                await breachMonitor.scanAll(entries: vaultStore.entries)
            }
            print("[ContentView] .task(id: phase) — isCloudAuth=\(syncService.isCloudAuthenticated) localEntries=\(vaultStore.entries.count)")
            if syncService.isCloudAuthenticated {
                do {
                    let merged = try await syncService.sync(localEntries: vaultStore.entries)
                    if !merged.isEmpty {
                        vaultStore.replaceEntries(merged)
                    } else {
                        print("[ContentView] sync returned empty — keeping \(vaultStore.entries.count) local entries")
                    }
                } catch {
                    print("[ContentView] sync error: \(error)")
                }
                // Sync cloud Pro status (Stripe subscription from web)
                await syncService.refreshCloudProStatus()
                subscriptionService.setCloudProStatus(syncService.cloudIsProUser)
            }
            await announcementsService.fetch()
            if mailService.isAuthenticated {
                async let a: () = mailService.fetchAliases()
                async let b: () = mailService.fetchEmails()
                _ = await (a, b)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fyxxVaultDataChanged)) { _ in
            guard syncService.isCloudAuthenticated, !isSyncing else { return }
            isSyncing = true
            Task {
                do {
                    let merged = try await syncService.sync(localEntries: vaultStore.entries)
                    if !merged.isEmpty {
                        vaultStore.replaceEntries(merged)
                    }
                } catch {
                    print("[ContentView] dataChanged sync error: \(error)")
                }
                isSyncing = false
            }
        }
        .onChange(of: syncService.isCloudAuthenticated) { _, isAuthenticated in
            print("[ContentView] isCloudAuthenticated changed → \(isAuthenticated)")
            guard isAuthenticated, authManager.phase == .vault, !isSyncing else { return }
            isSyncing = true
            Task {
                do {
                    let merged = try await syncService.sync(localEntries: vaultStore.entries)
                    if !merged.isEmpty {
                        vaultStore.replaceEntries(merged)
                        print("[ContentView] isCloudAuth sync OK — \(merged.count) entries")
                    } else {
                        print("[ContentView] isCloudAuth sync returned empty — keeping \(vaultStore.entries.count) local")
                    }
                } catch {
                    print("[ContentView] isCloudAuth sync error: \(error)")
                }
                isSyncing = false
                // Sync cloud Pro status
                subscriptionService.setCloudProStatus(syncService.cloudIsProUser)
                await mailService.fetchAliases()
                await mailService.fetchEmails()
            }
        }
        .onChange(of: syncService.cloudIsProUser) { _, isPro in
            subscriptionService.setCloudProStatus(isPro)
        }
        .onChange(of: scenePhase) { _, newValue in
            appLock.handleScenePhase(newValue, userAuthenticated: authManager.phase == .vault)
            // Refresh all data when coming back to foreground
            if newValue == .active && authManager.phase == .vault {
                Task {
                    if syncService.isCloudAuthenticated && !isSyncing {
                        isSyncing = true
                        do {
                            let merged = try await syncService.sync(localEntries: vaultStore.entries)
                            if !merged.isEmpty {
                                vaultStore.replaceEntries(merged)
                            }
                        } catch {
                            print("[ContentView] foreground sync error: \(error)")
                        }
                        isSyncing = false
                        // Refresh cloud Pro status
                        await syncService.refreshCloudProStatus()
                        subscriptionService.setCloudProStatus(syncService.cloudIsProUser)
                    }
                    if mailService.isAuthenticated {
                        async let a: () = mailService.fetchAliases()
                        async let b: () = mailService.fetchEmails()
                        _ = await (a, b)
                    }
                    await announcementsService.fetch()
                    if supportService.isAuthenticated {
                        await supportService.fetchTickets()
                    }
                }
            }
        }
        .onChange(of: authManager.phase) { _, phase in
            if phase == .vault {
                // Check if this is a different account than last time
                let lastEmail = UserDefaults.standard.string(forKey: "fyxxvault.last.account.email")
                let currentEmail = authManager.currentEmail
                if let lastEmail, lastEmail != currentEmail, currentEmail != "Compte local" {
                    // Different account — clear local vault to prevent data leak
                    vaultStore.clearLocalVault()
                }
                UserDefaults.standard.set(currentEmail, forKey: "fyxxvault.last.account.email")
                appLock.activateForVaultEntry()
            } else {
                appLock.forceUnlock()
            }
        }
        .onChange(of: authManager.panicTriggered) { _, triggered in
            guard triggered else { return }
            vaultStore.wipeVaultForPanicMode()
            authManager.logout()
            authManager.clearPanicFlag()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fyxxVaultBiometricLimitReached)) { _ in
            vaultStore.wipeVaultForPanicMode()
            authManager.logout()
            appLock.forceUnlock()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fyxxVaultScreenshotDetected)) { _ in
            authManager.logout()
            appLock.forceUnlock()
        }
        // Recovery key sheet (shown once, immediately after registration)
        .sheet(item: Binding(
            get: { authManager.pendingRecoveryKey.map { RecoveryKeyWrapper(key: $0) } },
            set: { if $0 == nil { authManager.dismissRecoveryKey() } }
        )) { wrapper in
            RecoveryKeyView(recoveryKey: wrapper.key) {
                authManager.dismissRecoveryKey()
            }
        }
    }
}

struct RecoveryKeyWrapper: Identifiable {
    let id = UUID()
    let key: String
}

#Preview {
    ContentView()
}
