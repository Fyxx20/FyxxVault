import SwiftUI
import Combine

// MARK: - Root View

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @StateObject private var vaultStore = VaultStore()
    @StateObject private var appLock = AppLockManager()
    @StateObject private var syncService = SyncService()
    @Environment(\.scenePhase) private var scenePhase

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
                        VaultDashboardView(authManager: authManager, vaultStore: vaultStore, syncService: syncService)
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
                            Text("Capture d'écran détectée")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Le coffre a été verrouillé.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            appLock.configureFromSettings()
            if authManager.phase == .vault {
                appLock.activateForVaultEntry()
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            appLock.handleScenePhase(newValue, userAuthenticated: authManager.phase == .vault)
        }
        .onChange(of: authManager.phase) { _, phase in
            if phase == .vault {
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
