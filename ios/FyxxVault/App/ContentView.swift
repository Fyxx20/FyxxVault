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
    @Environment(\.scenePhase) private var scenePhase
    /// Debounce flag to avoid overlapping sync requests
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
                        VaultDashboardView(authManager: authManager, vaultStore: vaultStore, syncService: syncService, breachMonitor: breachMonitor, maskedEmailService: maskedEmailService, subscriptionService: subscriptionService)
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
            if authManager.phase == .vault {
                appLock.activateForVaultEntry()
            }
        }
        .task(id: authManager.phase) {
            if authManager.phase == .vault && breachMonitor.shouldAutoScan() && subscriptionService.isProUser {
                await breachMonitor.scanAll(entries: vaultStore.entries)
            }
            // Auto-sync on vault entry
            if authManager.phase == .vault && syncService.isCloudAuthenticated {
                let merged = try? await syncService.sync(localEntries: vaultStore.entries)
                if let merged { vaultStore.replaceEntries(merged) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fyxxVaultDataChanged)) { _ in
            guard syncService.isCloudAuthenticated, !isSyncing else { return }
            isSyncing = true
            Task {
                let merged = try? await syncService.sync(localEntries: vaultStore.entries)
                if let merged { vaultStore.replaceEntries(merged) }
                isSyncing = false
            }
        }
        .onChange(of: syncService.isCloudAuthenticated) { _, isAuthenticated in
            // When SyncService becomes authenticated (e.g. background login on Path A),
            // trigger a sync to pull remote vault items.
            guard isAuthenticated, authManager.phase == .vault, !isSyncing else { return }
            isSyncing = true
            Task {
                let merged = try? await syncService.sync(localEntries: vaultStore.entries)
                if let merged { vaultStore.replaceEntries(merged) }
                isSyncing = false
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            appLock.handleScenePhase(newValue, userAuthenticated: authManager.phase == .vault)
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
