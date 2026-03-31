import SwiftUI

// MARK: - AuthView — Cinematic Trust Design

struct AuthView: View {
    @ObservedObject var authManager: AuthManager

    // MARK: - Auth State
    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var panicPassword = ""
    @State private var showRecoveryEntry = false
    @State private var recoveryKeyInput = ""
    @State private var recoveryError = ""

    // MARK: - UI State
    @State private var errorShake = false
    @State private var isLoading = false
    @State private var appeared = false
    @State private var shimmerOffset: CGFloat = -400

    // MARK: - Mode Enum

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

    // MARK: - Body

    var body: some View {
        ZStack {
            darkBackground
            backgroundOrbs
            mainContent
        }
        .ignoresSafeArea(edges: .top)
        .animation(.easeInOut(duration: 0.35), value: mode)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: showRecoveryEntry)
        .animation(.easeInOut(duration: 0.25), value: password.isEmpty)
        .onAppear { startAnimations() }
    }
}

// MARK: - Background Layer

private extension AuthView {

    var darkBackground: some View {
        FVAnimatedBackground()
            .ignoresSafeArea()
    }

    var backgroundOrbs: some View {
        ZStack {
            cyanOrb
            violetOrb
        }
        .ignoresSafeArea()
    }

    var cyanOrb: some View {
        Circle()
            .fill(FVColor.cyan.opacity(0.04))
            .frame(width: 300, height: 300)
            .blur(radius: 120)
            .offset(x: -120, y: -280)
    }

    var violetOrb: some View {
        Circle()
            .fill(FVColor.violet.opacity(0.04))
            .frame(width: 300, height: 300)
            .blur(radius: 120)
            .offset(x: 120, y: 280)
    }
}

// MARK: - Main Content

private extension AuthView {

    var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: 60)
                logoRow
                titleSection
                glassCard
                    .padding(.horizontal, 20)
                toggleModeLink
                footerEncryption
                Spacer().frame(height: 32)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
        }
    }
}

// MARK: - Logo Row

private extension AuthView {

    var logoRow: some View {
        HStack(spacing: 12) {
            logoIcon
            logoTitle
        }
    }

    var logoIcon: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [FVColor.cyan, FVColor.violet],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 48, height: 48)
            .overlay(lockIconOverlay)
            .shadow(color: FVColor.cyan.opacity(0.15), radius: 12, y: 4)
    }

    var lockIconOverlay: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
    }

    var logoTitle: some View {
        Text("FyxxVault")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
    }
}

// MARK: - Title Section

private extension AuthView {

    var titleSection: some View {
        VStack(spacing: 6) {
            modeTitleText
            subtitleText
        }
    }

    var modeTitleText: some View {
        Text(mode == .login ? "Connexion" : "Inscription")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
    }

    var subtitleText: some View {
        Text("Acc\u{00E8}de \u{00E0} ton coffre s\u{00E9}curis\u{00E9}")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(FVColor.smoke)
    }
}

// MARK: - Glass Card

private extension AuthView {

    var glassCard: some View {
        VStack(spacing: 20) {
            tabSelector
            emailField
            passwordField
            registerFields
            errorMessage
            submitButton
            loginRecoverySection
        }
        .padding(24)
        .background(glassCardFill)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(glassCardBorder)
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
    }

    var glassCardFill: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.04))
    }

    var glassCardBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
    }
}

// MARK: - Tab Selector

private extension AuthView {

    var tabSelector: some View {
        ZStack(alignment: .leading) {
            tabSelectorTrack
            tabSelectorIndicator
            tabSelectorButtons
        }
        .frame(height: 44)
    }

    var tabSelectorTrack: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(FVColor.abyss.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
    }

    var tabSelectorIndicator: some View {
        GeometryReader { geo in
            let halfW = geo.size.width / 2
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [FVColor.cyan, FVColor.violet],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: halfW - 8)
                .offset(x: mode == .login ? 4 : halfW + 4)
                .animation(.spring(response: 0.38, dampingFraction: 0.78), value: mode)
        }
        .padding(.vertical, 4)
    }

    var tabSelectorButtons: some View {
        HStack(spacing: 0) {
            ForEach(AuthMode.allCases) { m in
                tabButton(for: m)
            }
        }
    }

    func tabButton(for m: AuthMode) -> some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                mode = m
            }
            fvHaptic(.light)
        } label: {
            tabButtonLabel(for: m)
        }
        .buttonStyle(.plain)
    }

    func tabButtonLabel(for m: AuthMode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: m == .login ? "lock.fill" : "person.badge.plus")
                .font(.system(size: 12, weight: .bold))
            Text(m.localizedName)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(mode == m ? .white : FVColor.smoke)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Form Fields

private extension AuthView {

    var emailField: some View {
        FVTextField(
            title: String(localized: "auth.field.email"),
            text: $email,
            keyboard: .email,
            contentType: .email
        )
    }

    var passwordField: some View {
        FVTextField(
            title: String(localized: "auth.field.master_password"),
            text: $password,
            secure: true,
            contentType: .password
        )
    }
}

// MARK: - Register Fields

private extension AuthView {

    @ViewBuilder
    var registerFields: some View {
        if mode == .register {
            registerPasswordRequirements
            registerConfirmField
            registerPanicField
        }
    }

    @ViewBuilder
    var registerPasswordRequirements: some View {
        if !password.isEmpty {
            passwordRequirementsCard
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.96, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                ))
        }
    }

    var registerConfirmField: some View {
        FVTextField(
            title: String(localized: "auth.field.confirm_password"),
            text: $confirmPassword,
            secure: true,
            contentType: .password
        )
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        ))
    }

    var registerPanicField: some View {
        VStack(alignment: .leading, spacing: 6) {
            FVTextField(
                title: String(localized: "auth.field.panic_password"),
                text: $panicPassword,
                secure: true
            )
            panicWarningLabel
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        ))
    }

    var panicWarningLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.orange.opacity(0.85))
            Text(String(localized: "auth.panic.description"))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.orange.opacity(0.75))
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Password Requirements Card

private extension AuthView {

    var passwordRequirementsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            requirementsHeader
            requirementsGrid
        }
        .padding(14)
        .background(requirementsCardBackground)
        .overlay(requirementsCardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: password)
    }

    var requirementsHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.badge.clock.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FVColor.cyan.opacity(0.8))
            Text(String(localized: "auth.password.requirements.title"))
                .font(FVFont.caption(11))
                .foregroundStyle(FVColor.smoke)
                .kerning(0.8)
            Spacer()
            strengthBars
        }
    }

    var strengthBars: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < passwordStrengthLevel ? strengthColor : Color.white.opacity(0.08))
                    .frame(width: 18, height: 4)
                    .animation(.spring(response: 0.3), value: passwordStrengthLevel)
            }
        }
    }

    var requirementsGrid: some View {
        VStack(spacing: 5) {
            requirementsRow1
            requirementsRow2
        }
    }

    var requirementsRow1: some View {
        HStack(spacing: 8) {
            FVRequirementRow(
                label: String(localized: "auth.password.requirement.length"),
                met: password.count >= 12
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            FVRequirementRow(
                label: String(localized: "auth.password.requirement.uppercase"),
                met: password.rangeOfCharacter(from: .uppercaseLetters) != nil
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var requirementsRow2: some View {
        HStack(spacing: 8) {
            FVRequirementRow(
                label: String(localized: "auth.password.requirement.digit"),
                met: password.rangeOfCharacter(from: .decimalDigits) != nil
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            FVRequirementRow(
                label: String(localized: "auth.password.requirement.special"),
                met: password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:,.<>?/\\\"'`~")) != nil
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var requirementsCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FVColor.abyss.opacity(0.55))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [strengthColor.opacity(0.05), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    var requirementsCardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(strengthColor.opacity(0.18), lineWidth: 1)
            .animation(.easeOut(duration: 0.3), value: passwordStrengthLevel)
    }
}

// MARK: - Password Strength

private extension AuthView {

    var passwordStrengthLevel: Int {
        var score = 0
        if password.count >= 12 { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        let specialChars = CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:,.<>?/\\\"'`~")
        if password.rangeOfCharacter(from: specialChars) != nil { score += 1 }
        return score
    }

    var strengthColor: Color {
        switch passwordStrengthLevel {
        case 0, 1: return FVColor.danger
        case 2: return FVColor.warning
        case 3: return FVColor.cyan
        default: return FVColor.success
        }
    }
}

// MARK: - Error Message

private extension AuthView {

    @ViewBuilder
    var errorMessage: some View {
        if !authManager.authError.isEmpty {
            errorMessageContent
        }
    }

    var errorMessageContent: some View {
        HStack(spacing: 10) {
            errorIcon
            errorText
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(errorBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .offset(x: errorShake ? -7 : 0)
        .animation(
            .spring(response: 0.08, dampingFraction: 0.25).repeatCount(5, autoreverses: true),
            value: errorShake
        )
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)),
            removal: .opacity.combined(with: .scale(scale: 0.95))
        ))
        .onChange(of: authManager.authError) { _, newValue in
            handleErrorChange(newValue)
        }
    }

    var errorIcon: some View {
        Image(systemName: "xmark.circle.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(FVColor.danger)
    }

    var errorText: some View {
        Text(authManager.authError)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(FVColor.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var errorBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FVColor.danger.opacity(0.10))
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(FVColor.danger.opacity(0.20), lineWidth: 1)
        }
    }

    func handleErrorChange(_ newValue: String) {
        guard !newValue.isEmpty else { return }
        errorShake = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            errorShake = true
            fvHaptic(.error)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            errorShake = false
        }
    }
}

// MARK: - Submit Button

private extension AuthView {

    var submitButton: some View {
        Button(action: handleSubmit) {
            submitButtonContent
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .scaleEffect(isLoading ? 0.98 : 1)
        .animation(.spring(response: 0.3), value: isLoading)
    }

    func handleSubmit() {
        fvHaptic(.medium)
        isLoading = true
        if mode == .login {
            authManager.login(email: email, password: password)
        } else {
            authManager.register(
                email: email,
                password: password,
                confirmPassword: confirmPassword,
                panicPassword: panicPassword
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            isLoading = false
        }
    }

    var submitButtonContent: some View {
        ZStack {
            submitButtonGradient
            submitButtonShimmer
            submitButtonLabel
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: FVColor.cyan.opacity(0.2), radius: 12, y: 4)
    }

    var submitButtonGradient: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [FVColor.cyan, FVColor.violet],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }

    var submitButtonShimmer: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.12), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .offset(x: shimmerOffset)
            .clipped()
    }

    var submitButtonLabel: some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.85)
            } else {
                submitButtonLabelContent
            }
        }
        .foregroundStyle(.white)
    }

    var submitButtonLabelContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 15, weight: .bold))
            Text(mode == .login
                 ? String(localized: "auth.button.login")
                 : String(localized: "auth.button.register"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
        }
    }
}

// MARK: - Recovery Section

private extension AuthView {

    @ViewBuilder
    var loginRecoverySection: some View {
        if mode == .login {
            orDivider
            recoveryToggleButton
            recoveryFormSection
        }
    }

    var orDivider: some View {
        HStack(spacing: 14) {
            dividerLine(leading: true)
            Text(String(localized: "auth.divider.or"))
                .font(FVFont.caption(10))
                .foregroundStyle(FVColor.smoke.opacity(0.7))
                .kerning(2)
                .padding(.horizontal, 4)
            dividerLine(leading: false)
        }
    }

    func dividerLine(leading: Bool) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: leading
                        ? [.clear, Color.white.opacity(0.1)]
                        : [Color.white.opacity(0.1), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }

    var recoveryToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                showRecoveryEntry.toggle()
                recoveryError = ""
            }
            fvHaptic(.light)
        } label: {
            recoveryToggleLabel
        }
        .buttonStyle(.plain)
    }

    var recoveryToggleLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: showRecoveryEntry ? "xmark.circle" : "key.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(showRecoveryEntry
                 ? String(localized: "auth.recovery.cancel")
                 : String(localized: "auth.recovery.forgot_password"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(FVColor.cyan)
    }

    @ViewBuilder
    var recoveryFormSection: some View {
        if showRecoveryEntry {
            recoveryForm
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.97, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
                ))
        }
    }
}

// MARK: - Recovery Form

private extension AuthView {

    var recoveryForm: some View {
        VStack(spacing: 14) {
            FVTextField(
                title: String(localized: "auth.recovery.field.key"),
                text: $recoveryKeyInput,
                icon: "key.horizontal.fill"
            )
            recoveryErrorLabel
            recoveryUnlockButton
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    var recoveryUnlockButton: some View {
        FVButton(
            title: String(localized: "auth.recovery.button.unlock"),
            icon: "lock.open.rotation",
            style: .secondary
        ) {
            if authManager.unlockWithRecoveryKey(recoveryKeyInput) {
                recoveryKeyInput = ""
                recoveryError = ""
                fvHaptic(.success)
            } else {
                recoveryError = String(localized: "auth.recovery.error.invalid")
                fvHaptic(.error)
            }
        }
    }

    @ViewBuilder
    var recoveryErrorLabel: some View {
        if !recoveryError.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FVColor.danger)
                Text(recoveryError)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.danger)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - Toggle Mode & Footer

private extension AuthView {

    var toggleModeLink: some View {
        HStack(spacing: 4) {
            toggleModePrompt
            toggleModeButton
        }
        .padding(.top, 4)
    }

    var toggleModePrompt: some View {
        Text(mode == .login
             ? "Pas encore de compte?"
             : "D\u{00E9}j\u{00E0} un compte?")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(FVColor.smoke)
    }

    var toggleModeButton: some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                mode = mode == .login ? .register : .login
            }
            fvHaptic(.light)
        } label: {
            Text(mode == .login
                 ? "Cr\u{00E9}er un compte"
                 : "Se connecter")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(FVColor.cyan)
        }
        .buttonStyle(.plain)
    }

    var footerEncryption: some View {
        Text("Chiffrement local AES-256 \u{00B7} Connexion s\u{00E9}curis\u{00E9}e")
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(FVColor.ash)
            .kerning(0.6)
            .padding(.top, 8)
    }
}

// MARK: - Animations

private extension AuthView {

    func startAnimations() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
            appeared = true
        }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: false).delay(0.2)) {
            shimmerOffset = 400
        }
    }
}

// MARK: - FVFloatingTag — Animated Feature Badge

struct FVFloatingTag: View {
    let text: String
    let color: Color
    let delay: Double

    @State private var floatOffset: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 5) {
            tagDot
            tagLabel
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .background(.ultraThinMaterial.opacity(0.3))
        .overlay(tagBorder)
        .clipShape(Capsule())
        .shadow(color: color.opacity(0.2), radius: 8, y: 2)
        .offset(y: floatOffset)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.7)
        .onAppear { startTagAnimations() }
    }

    private var tagDot: some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
            .shadow(color: color.opacity(0.8), radius: 4)
    }

    private var tagLabel: some View {
        Text(text)
            .font(FVFont.caption(10))
            .foregroundStyle(color)
            .kerning(0.6)
    }

    private var tagBorder: some View {
        Capsule()
            .strokeBorder(color.opacity(0.28), lineWidth: 1)
    }

    private func startTagAnimations() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(delay)) {
            appeared = true
        }
        withAnimation(.easeInOut(duration: 2.8 + delay * 0.6).repeatForever(autoreverses: true).delay(delay)) {
            floatOffset = -5
        }
    }
}
