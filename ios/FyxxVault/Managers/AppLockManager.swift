import SwiftUI
import LocalAuthentication
import Combine

extension Notification.Name {
    static let fyxxVaultBiometricLimitReached = Notification.Name("fyxxvault.biometric.limit.reached")
    static let fyxxVaultScreenshotDetected = Notification.Name("fyxxvault.screenshot.detected")
}

@MainActor
final class AppLockManager: ObservableObject {
    @Published var isLocked = false
    @Published var lockError = ""
    @Published var screenshotDetected = false

    private var backgroundDate: Date?
    private var failedBiometricAttempts = 0
    /// Reduced from 10 to 5 to match iOS's own Face ID/Touch ID limit
    private let biometricFailureLimit = 5

    func configureFromSettings() {
        if UserDefaults.standard.object(forKey: SettingsKey.autoLockEnabled) == nil {
            UserDefaults.standard.set(true, forKey: SettingsKey.autoLockEnabled)
        }
        if UserDefaults.standard.object(forKey: SettingsKey.autoLockMinutes) == nil {
            UserDefaults.standard.set(2, forKey: SettingsKey.autoLockMinutes)
        }
        if UserDefaults.standard.object(forKey: SettingsKey.biometricUnlock) == nil {
            UserDefaults.standard.set(false, forKey: SettingsKey.biometricUnlock)
        }
        if UserDefaults.standard.object(forKey: SettingsKey.clipboardAutoClear) == nil {
            UserDefaults.standard.set(true, forKey: SettingsKey.clipboardAutoClear)
        }
        if UserDefaults.standard.object(forKey: SettingsKey.clipboardDelay) == nil {
            UserDefaults.standard.set(30, forKey: SettingsKey.clipboardDelay)
        }

        // Register for screenshot detection
        registerScreenshotObserver()
    }

    func activateForVaultEntry() {
        let biometric = UserDefaults.standard.bool(forKey: SettingsKey.biometricUnlock)
        if biometric {
            isLocked = true
            Task { _ = await unlockWithBiometrics() }
        } else {
            // No biometric configured — don't lock on entry
            isLocked = false
        }
    }

    func handleScenePhase(_ scenePhase: ScenePhase, userAuthenticated: Bool) {
        guard userAuthenticated else { return }
        switch scenePhase {
        case .background, .inactive:
            backgroundDate = Date()
        case .active:
            let autoLockEnabled = UserDefaults.standard.bool(forKey: SettingsKey.autoLockEnabled)
            guard autoLockEnabled else { return }
            let minutes = max(UserDefaults.standard.integer(forKey: SettingsKey.autoLockMinutes), 1)
            if let backgroundDate {
                let elapsed = Date().timeIntervalSince(backgroundDate)
                if elapsed >= Double(minutes * 60) {
                    isLocked = true
                }
            }
        @unknown default:
            break
        }
    }

    func forceUnlock() {
        isLocked = false
        lockError = ""
        backgroundDate = nil
        failedBiometricAttempts = 0
    }

    func unlockWithBiometrics() async -> Bool {
        lockError = ""
        let enabled = UserDefaults.standard.bool(forKey: SettingsKey.biometricUnlock)
        guard enabled else {
            isLocked = false
            return true
        }

        let context = LAContext()
        context.localizedCancelTitle = "Annuler"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            isLocked = true
            lockError = "Biométrie indisponible."
            return false
        }

        #if os(iOS)
        if context.biometryType == .faceID,
           Bundle.main.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") == nil {
            isLocked = true
            lockError = "Face ID non configuré. Active Touch ID ou ajoute NSFaceIDUsageDescription au Info.plist."
            return false
        }
        #endif

        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Déverrouiller FyxxVault"
            )
            isLocked = !result
            failedBiometricAttempts = 0
            return result
        } catch {
            failedBiometricAttempts += 1
            isLocked = true
            if failedBiometricAttempts >= biometricFailureLimit {
                NotificationCenter.default.post(name: .fyxxVaultBiometricLimitReached, object: nil)
                failedBiometricAttempts = 0
            }
            lockError = "Échec biométrique (\(failedBiometricAttempts)/\(biometricFailureLimit))."
            return false
        }
    }

    // MARK: Screenshot Protection

    private func registerScreenshotObserver() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.screenshotDetected = true
                // Lock the vault when a screenshot is taken
                self?.isLocked = true
                NotificationCenter.default.post(name: .fyxxVaultScreenshotDetected, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.screenshotDetected = false
                }
            }
        }
        #endif
    }
}
