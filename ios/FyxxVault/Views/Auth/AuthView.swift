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
        var localizedName: String {
            switch self {
            case .login: return String(localized: "auth.mode.login")
            case .register: return String(localized: "auth.mode.register")
            }
        }
    }

    var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "auth.password.requirements.title"))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
            requirements
        }
        .padding(10)
        .background(FVColor.abyss.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder var requirements: some View {
        FVRequirementRow(label: String(localized: "auth.password.requirement.length"), met: password.count >= 12)
        FVRequirementRow(label: String(localized: "auth.password.requirement.uppercase"), met: password.rangeOfCharacter(from: .uppercaseLetters) != nil)
        FVRequirementRow(label: String(localized: "auth.password.requirement.digit"), met: password.rangeOfCharacter(from: .decimalDigits) != nil)
        FVRequirementRow(label: String(localized: "auth.password.requirement.special"), met: password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:,.<>?/\\\"'`~")) != nil)
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            FVBrandHeader(subtitle: String(localized: "auth.header.subtitle"))

            HStack(spacing: 8) {
                FVTag(text: "AES-256", color: FVColor.cyan)
                FVTag(text: "MFA", color: FVColor.violet)
                FVTag(text: "Local", color: FVColor.success)
            }

            VStack(spacing: 16) {
                Picker("Mode", selection: $mode) {
                    ForEach(AuthMode.allCases) { m in Text(m.localizedName).tag(m) }
                }
                .pickerStyle(.segmented)

                FVTextField(title: String(localized: "auth.field.email"), text: $email, keyboard: .email, contentType: .email)
                FVTextField(title: String(localized: "auth.field.master_password"), text: $password, secure: true, contentType: .password)

                if mode == .register {
                    if !password.isEmpty { passwordRequirements }
                    FVTextField(title: String(localized: "auth.field.confirm_password"), text: $confirmPassword, secure: true, contentType: .password)
                    FVTextField(title: String(localized: "auth.field.panic_password"), text: $panicPassword, secure: true)
                    Text(String(localized: "auth.panic.description"))
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

                FVButton(title: mode == .login ? String(localized: "auth.button.login") : String(localized: "auth.button.register")) {
                    if mode == .login {
                        authManager.login(email: email, password: password)
                    } else {
                        authManager.register(email: email, password: password, confirmPassword: confirmPassword, panicPassword: panicPassword)
                    }
                }

                if mode == .login {
                    Button(showRecoveryEntry ? String(localized: "auth.recovery.cancel") : String(localized: "auth.recovery.forgot_password")) {
                        showRecoveryEntry.toggle()
                        recoveryError = ""
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.violet.opacity(0.9))

                    if showRecoveryEntry {
                        FVTextField(title: String(localized: "auth.recovery.field.key"), text: $recoveryKeyInput)
                        if !recoveryError.isEmpty {
                            Text(recoveryError).foregroundStyle(FVColor.danger).font(.system(size: 12))
                        }
                        FVButton(title: String(localized: "auth.recovery.button.unlock")) {
                            if authManager.unlockWithRecoveryKey(recoveryKeyInput) {
                                recoveryKeyInput = ""
                                recoveryError = ""
                            } else {
                                recoveryError = String(localized: "auth.recovery.error.invalid")
                            }
                        }
                    }
                }
            }
            .fvGlass()

            Text(String(localized: "auth.footer.tagline"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))

            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.25), value: mode)
    }
}
