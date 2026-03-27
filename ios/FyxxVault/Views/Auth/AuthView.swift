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
    @State private var shieldPulse = false
    @State private var errorShake = false
    @State private var isLoading = false

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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 10)
                shieldHeader
                FVBrandHeader(subtitle: String(localized: "auth.header.subtitle"), compact: true)
                tagRow
                formCard
                footerSection
                Spacer(minLength: 20)
            }
        }
        .scrollIndicators(.hidden)
        .animation(.easeInOut(duration: 0.3), value: mode)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showRecoveryEntry)
        .animation(.easeInOut(duration: 0.25), value: password.isEmpty)
    }

    // MARK: - Shield Header with Pulsing Glow

    private var shieldHeader: some View {
        ZStack {
            // Outer pulsing glow
            Circle()
                .fill(RadialGradient(
                    colors: [FVColor.cyan.opacity(0.2), FVColor.violet.opacity(0.08), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 80
                ))
                .frame(width: 160, height: 160)
                .scaleEffect(shieldPulse ? 1.12 : 0.95)
                .opacity(shieldPulse ? 0.8 : 0.4)

            // Inner glow ring
            Circle()
                .stroke(
                    RadialGradient(
                        colors: [FVColor.cyan.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 25,
                        endRadius: 45
                    ),
                    lineWidth: 2
                )
                .frame(width: 80, height: 80)
                .scaleEffect(shieldPulse ? 1.05 : 1.0)

            Circle()
                .fill(FVGradient.cyanToViolet)
                .frame(width: 64, height: 64)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1.2))
                .shadow(color: FVColor.cyan.opacity(0.4), radius: 24, y: 4)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                shieldPulse = true
            }
        }
    }

    // MARK: - Tag Row

    private var tagRow: some View {
        HStack(spacing: 8) {
            FVTag(text: "AES-256", color: FVColor.cyan)
            FVTag(text: "MFA", color: FVColor.violet)
            FVTag(text: "Local", color: FVColor.success)
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 16) {
            modePicker
            FVTextField(title: String(localized: "auth.field.email"), text: $email, keyboard: .email, contentType: .email)
            FVTextField(title: String(localized: "auth.field.master_password"), text: $password, secure: true, contentType: .password)
            registerFields
            errorMessage
            submitButton
            loginRecoverySection
        }
        .fvGlass()
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(AuthMode.allCases) { m in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        mode = m
                    }
                    fvHaptic(.light)
                } label: {
                    Text(m.localizedName)
                        .font(FVFont.label(13))
                        .foregroundStyle(mode == m ? .white : FVColor.smoke)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Group {
                                if mode == m {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(FVGradient.cyanToViolet.opacity(0.7))
                                        .shadow(color: FVColor.cyan.opacity(0.2), radius: 8, y: 2)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var registerFields: some View {
        if mode == .register {
            if !password.isEmpty {
                passwordRequirements
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            }
            FVTextField(title: String(localized: "auth.field.confirm_password"), text: $confirmPassword, secure: true, contentType: .password)
            FVTextField(title: String(localized: "auth.field.panic_password"), text: $panicPassword, secure: true)
            Text(String(localized: "auth.panic.description"))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.orange.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "auth.password.requirements.title"))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
            FVRequirementRow(label: String(localized: "auth.password.requirement.length"), met: password.count >= 12)
            FVRequirementRow(label: String(localized: "auth.password.requirement.uppercase"), met: password.rangeOfCharacter(from: .uppercaseLetters) != nil)
            FVRequirementRow(label: String(localized: "auth.password.requirement.digit"), met: password.rangeOfCharacter(from: .decimalDigits) != nil)
            FVRequirementRow(label: String(localized: "auth.password.requirement.special"), met: password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:,.<>?/\\\"'`~")) != nil)
        }
        .padding(10)
        .background(FVColor.abyss.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: password)
    }

    @ViewBuilder
    private var errorMessage: some View {
        if !authManager.authError.isEmpty {
            Text(authManager.authError)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: errorShake ? -8 : 0)
                .animation(
                    .spring(response: 0.1, dampingFraction: 0.2).repeatCount(4, autoreverses: true),
                    value: errorShake
                )
                .onChange(of: authManager.authError) { _, newValue in
                    if !newValue.isEmpty {
                        errorShake = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            errorShake = true
                            fvHaptic(.error)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            errorShake = false
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var submitButton: some View {
        Button {
            fvHaptic(.medium)
            isLoading = true
            if mode == .login {
                authManager.login(email: email, password: password)
            } else {
                authManager.register(email: email, password: password, confirmPassword: confirmPassword, panicPassword: panicPassword)
            }
            // Reset loading after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isLoading = false
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Text(mode == .login ? String(localized: "auth.button.login") : String(localized: "auth.button.register"))
                        .font(FVFont.label(15))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(FVGradient.cyanToViolet)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: FVColor.cyan.opacity(0.25), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    // MARK: - Login Recovery Section

    @ViewBuilder
    private var loginRecoverySection: some View {
        if mode == .login {
            // Subtle divider
            HStack(spacing: 12) {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                Text(String(localized: "auth.divider.or"))
                    .font(FVFont.caption(10))
                    .foregroundStyle(FVColor.smoke)
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
            }
            .padding(.vertical, 4)

            Button(showRecoveryEntry ? String(localized: "auth.recovery.cancel") : String(localized: "auth.recovery.forgot_password")) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showRecoveryEntry.toggle()
                    recoveryError = ""
                }
                fvHaptic(.light)
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(FVColor.violet.opacity(0.9))

            if showRecoveryEntry {
                recoveryForm
            }
        }
    }

    private var recoveryForm: some View {
        VStack(spacing: 12) {
            FVTextField(title: String(localized: "auth.recovery.field.key"), text: $recoveryKeyInput)
            if !recoveryError.isEmpty {
                Text(recoveryError).foregroundStyle(FVColor.danger).font(.system(size: 12))
            }
            FVButton(title: String(localized: "auth.recovery.button.unlock"), style: .secondary) {
                if authManager.unlockWithRecoveryKey(recoveryKeyInput) {
                    recoveryKeyInput = ""
                    recoveryError = ""
                } else {
                    recoveryError = String(localized: "auth.recovery.error.invalid")
                    fvHaptic(.error)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            Text(String(localized: "auth.footer.tagline"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))

            Text("FyxxVault v1.0")
                .font(FVFont.caption(10))
                .foregroundStyle(FVColor.smoke.opacity(0.3))
        }
    }
}
