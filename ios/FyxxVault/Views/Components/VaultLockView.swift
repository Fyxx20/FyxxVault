import SwiftUI

struct VaultLockView: View {
    @ObservedObject var appLock: AppLockManager
    @ObservedObject var authManager: AuthManager
    @State private var masterPassword = ""
    @State private var masterUnlockError = ""
    @State private var showRecoveryKeyEntry = false
    @State private var recoveryKeyInput = ""
    @State private var recoveryKeyError = ""

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            FVBrandHeader(subtitle: String(localized: "lock.header.subtitle"))
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(FVColor.silver)

                if !appLock.lockError.isEmpty {
                    Text(appLock.lockError)
                        .foregroundStyle(FVColor.danger.opacity(0.9))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }

                FVButton(title: String(localized: "lock.button.biometric")) {
                    Task { _ = await appLock.unlockWithBiometrics() }
                }

                FVTextField(title: String(localized: "lock.field.master_password"), text: $masterPassword, secure: true)
                if !masterUnlockError.isEmpty {
                    Text(masterUnlockError)
                        .foregroundStyle(FVColor.danger.opacity(0.9))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                FVButton(title: String(localized: "lock.button.password")) {
                    if authManager.verifyMasterPasswordForVaultUnlock(masterPassword) {
                        appLock.forceUnlock()
                        masterPassword = ""
                        masterUnlockError = ""
                    } else {
                        masterUnlockError = String(localized: "lock.error.wrong_password")
                    }
                }

                if showRecoveryKeyEntry {
                    FVTextField(title: String(localized: "lock.field.recovery_key"), text: $recoveryKeyInput)
                    if !recoveryKeyError.isEmpty {
                        Text(recoveryKeyError).foregroundStyle(FVColor.danger.opacity(0.9))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    FVButton(title: String(localized: "lock.button.recovery")) {
                        if authManager.unlockWithRecoveryKey(recoveryKeyInput) {
                            appLock.forceUnlock()
                            recoveryKeyInput = ""
                            recoveryKeyError = ""
                        } else {
                            recoveryKeyError = String(localized: "lock.error.invalid_recovery")
                        }
                    }
                }

                Button(showRecoveryKeyEntry ? String(localized: "lock.button.cancel_recovery") : String(localized: "lock.button.use_recovery")) {
                    showRecoveryKeyEntry.toggle()
                    recoveryKeyError = ""
                }
                .foregroundStyle(FVColor.violet.opacity(0.9))
                .font(.system(size: 13, weight: .medium, design: .rounded))

                Button(String(localized: "lock.button.back_to_login")) { authManager.logout(); appLock.forceUnlock() }
                    .foregroundStyle(FVColor.silver.opacity(0.84))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .fvGlass()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20).padding(.vertical, 28)
    }
}
