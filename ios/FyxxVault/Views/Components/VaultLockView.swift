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
            FVBrandHeader(subtitle: "Coffre verrouillé")
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(FVColor.silver)

                if !appLock.lockError.isEmpty {
                    Text(appLock.lockError)
                        .foregroundStyle(FVColor.danger.opacity(0.9))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }

                FVButton(title: "Déverrouiller avec Face ID / Touch ID") {
                    Task { _ = await appLock.unlockWithBiometrics() }
                }

                FVTextField(title: "Mot de passe maître", text: $masterPassword, secure: true)
                if !masterUnlockError.isEmpty {
                    Text(masterUnlockError)
                        .foregroundStyle(FVColor.danger.opacity(0.9))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                FVButton(title: "Déverrouiller avec mot de passe") {
                    if authManager.verifyMasterPasswordForVaultUnlock(masterPassword) {
                        appLock.forceUnlock()
                        masterPassword = ""
                        masterUnlockError = ""
                    } else {
                        masterUnlockError = "Mot de passe maître incorrect."
                    }
                }

                if showRecoveryKeyEntry {
                    FVTextField(title: "Clé de récupération (XXXX-XXXX-...)", text: $recoveryKeyInput)
                    if !recoveryKeyError.isEmpty {
                        Text(recoveryKeyError).foregroundStyle(FVColor.danger.opacity(0.9))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    FVButton(title: "Déverrouiller avec clé de récupération") {
                        if authManager.unlockWithRecoveryKey(recoveryKeyInput) {
                            appLock.forceUnlock()
                            recoveryKeyInput = ""
                            recoveryKeyError = ""
                        } else {
                            recoveryKeyError = "Clé de récupération invalide."
                        }
                    }
                }

                Button(showRecoveryKeyEntry ? "Annuler la récupération" : "Utiliser la clé de récupération") {
                    showRecoveryKeyEntry.toggle()
                    recoveryKeyError = ""
                }
                .foregroundStyle(FVColor.violet.opacity(0.9))
                .font(.system(size: 13, weight: .medium, design: .rounded))

                Button("Retour à la connexion") { authManager.logout(); appLock.forceUnlock() }
                    .foregroundStyle(FVColor.silver.opacity(0.84))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .fvGlass()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20).padding(.vertical, 28)
    }
}
