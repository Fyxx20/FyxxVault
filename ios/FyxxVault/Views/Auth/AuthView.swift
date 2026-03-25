import SwiftUI

struct AuthView: View {
    @ObservedObject var authManager: AuthManager
    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var panicPassword = ""
    @State private var showRecoveryEntry = false
    @State private var recoveryKeyInput = ""
    @State private var recoveryError = ""

    enum AuthMode: String, CaseIterable, Identifiable {
        case login = "Connexion"
        case register = "Inscription"
        var id: String { rawValue }
    }

    var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Exigences du mot de passe maître:")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
            requirements
        }
        .padding(10)
        .background(FVColor.abyss.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder var requirements: some View {
        FVRequirementRow(label: "12 caractères minimum", met: password.count >= 12)
        FVRequirementRow(label: "1 majuscule", met: password.rangeOfCharacter(from: .uppercaseLetters) != nil)
        FVRequirementRow(label: "1 chiffre", met: password.rangeOfCharacter(from: .decimalDigits) != nil)
        FVRequirementRow(label: "1 caractère spécial (!@#$...)", met: password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:,.<>?/\\\"'`~")) != nil)
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            FVBrandHeader(subtitle: "Accès sécurisé à ton coffre")

            HStack(spacing: 8) {
                FVTag(text: "AES-256", color: FVColor.cyan)
                FVTag(text: "MFA", color: FVColor.violet)
                FVTag(text: "Local", color: FVColor.success)
            }

            VStack(spacing: 16) {
                Picker("Mode", selection: $mode) {
                    ForEach(AuthMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)

                FVTextField(title: "Email", text: $email, keyboard: .email, contentType: .email)
                FVTextField(title: "Mot de passe maître", text: $password, secure: true, contentType: .password)

                if mode == .register {
                    if !password.isEmpty { passwordRequirements }
                    FVTextField(title: "Confirmer le mot de passe", text: $confirmPassword, secure: true, contentType: .password)
                    FVTextField(title: "Mot de passe panic (optionnel)", text: $panicPassword, secure: true)
                    Text("Le mot de passe panic efface immédiatement tout le coffre si utilisé à la place du mot de passe maître.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !authManager.authError.isEmpty {
                    Text(authManager.authError)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(FVColor.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                FVButton(title: mode == .login ? "Se connecter" : "Créer le compte") {
                    if mode == .login {
                        authManager.login(email: email, password: password)
                    } else {
                        authManager.register(email: email, password: password, confirmPassword: confirmPassword, panicPassword: panicPassword)
                    }
                }

                if mode == .login {
                    Button(showRecoveryEntry ? "Annuler" : "Mot de passe oublié? Utiliser la clé de récupération") {
                        showRecoveryEntry.toggle()
                        recoveryError = ""
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.violet.opacity(0.9))

                    if showRecoveryEntry {
                        FVTextField(title: "Clé de récupération (XXXX-XXXX-...)", text: $recoveryKeyInput)
                        if !recoveryError.isEmpty {
                            Text(recoveryError).foregroundStyle(FVColor.danger).font(.system(size: 12))
                        }
                        FVButton(title: "Accéder avec la clé de récupération") {
                            if authManager.unlockWithRecoveryKey(recoveryKeyInput) {
                                recoveryKeyInput = ""
                                recoveryError = ""
                            } else {
                                recoveryError = "Clé de récupération invalide."
                            }
                        }
                    }
                }
            }
            .fvGlass()

            Text("Connexion locale, chiffrée, sans compromis.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))

            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.25), value: mode)
    }
}
