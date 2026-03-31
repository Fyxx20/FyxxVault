import SwiftUI
import LocalAuthentication

struct VaultLockView: View {
    @ObservedObject var appLock: AppLockManager
    @ObservedObject var authManager: AuthManager

    @State private var masterPassword = ""
    @State private var masterUnlockError = ""
    @State private var showRecoveryKeyEntry = false
    @State private var recoveryKeyInput = ""
    @State private var recoveryKeyError = ""
    @State private var revealPassword = false
    @State private var biometricAvailable = false
    @State private var biometricIcon = "faceid"
    @State private var biometricLabel = "Face ID"

    // Animation states
    @State private var appeared = false
    @State private var glowPulse = false
    @State private var lockFloat: CGFloat = 0
    @State private var shimmerOffset: CGFloat = -1.2
    @State private var passwordFieldFocused = false
    @State private var pulseRing = false
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        ZStack {
            backgroundLayer
            scrollContent
        }
        .onAppear(perform: onAppearSetup)
        .onChange(of: isPasswordFocused) { _, focused in
            withAnimation(.easeInOut(duration: 0.25)) {
                passwordFieldFocused = focused
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            FVAnimatedBackground()
            backgroundOrbs
        }
    }

    private var backgroundOrbs: some View {
        ZStack {
            Circle()
                .fill(FVColor.cyan.opacity(0.04))
                .frame(width: 300, height: 300)
                .blur(radius: 120)
                .offset(x: -100, y: -260)

            Circle()
                .fill(FVColor.violet.opacity(0.04))
                .frame(width: 300, height: 300)
                .blur(radius: 120)
                .offset(x: 100, y: 260)
        }
        .ignoresSafeArea()
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 70)
                headerSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)
                Spacer().frame(height: 32)
                glassCard
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
                Spacer().frame(height: 24)
                footerLinks
                    .opacity(appeared ? 1 : 0)
                Spacer().frame(height: 20)
                securityBadge
                    .opacity(appeared ? 1 : 0)
                Spacer().frame(height: 40)
            }
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            headerLogo
            headerTitles
        }
    }

    private var headerLogo: some View {
        ZStack {
            logoGlowShadow
            logoSquare
            logoIcon
        }
    }

    private var logoGlowShadow: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(FVColor.cyan.opacity(glowPulse ? 0.12 : 0.04))
            .frame(width: 70, height: 70)
            .blur(radius: 10)
    }

    private var logoSquare: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(FVGradient.cyanToViolet)
            .frame(width: 56, height: 56)
            .scaleEffect(glowPulse ? 1.02 : 1.0)
            .shadow(color: FVColor.cyan.opacity(glowPulse ? 0.25 : 0.12), radius: 16, y: 4)
    }

    private var logoIcon: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
    }

    private var headerTitles: some View {
        VStack(spacing: 6) {
            Text("Déverrouiller ton coffre")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            headerEmail
        }
    }

    @ViewBuilder
    private var headerEmail: some View {
        let email = authManager.currentEmail
        if !email.isEmpty {
            Text(email)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.cyan)
                .lineLimit(1)
        }
    }

    // MARK: - Glass Card

    private var glassCard: some View {
        VStack(spacing: 0) {
            lockIconSection
            cardLabel
            cardFormContent
        }
        .background(glassCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(glassCardBorder)
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .padding(.horizontal, 24)
    }

    private var glassCardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.04))
    }

    private var glassCardBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
    }

    // MARK: - Lock Icon Section

    private var lockIconSection: some View {
        ZStack {
            lockPulseRing
            lockCircleBackground
            lockCircleBorder
            lockImage
        }
        .offset(y: lockFloat)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    private var lockPulseRing: some View {
        Circle()
            .stroke(FVColor.cyan.opacity(pulseRing ? 0 : 0.20), lineWidth: 1)
            .frame(width: 72, height: 72)
            .scaleEffect(pulseRing ? 1.4 : 1.0)
    }

    private var lockCircleBackground: some View {
        Circle()
            .fill(Color.white.opacity(0.03))
            .frame(width: 72, height: 72)
    }

    private var lockCircleBorder: some View {
        Circle()
            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            .frame(width: 72, height: 72)
    }

    private var lockImage: some View {
        Image(systemName: "lock.shield.fill")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(FVGradient.cyanToViolet)
    }

    // MARK: - Card Label

    private var cardLabel: some View {
        Text("MOT DE PASSE MAÎTRE")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(3)
            .foregroundStyle(FVColor.smoke)
            .padding(.bottom, 18)
    }

    // MARK: - Card Form Content

    private var cardFormContent: some View {
        VStack(spacing: 12) {
            biometricSection
            passwordFieldSection
            errorSection
            unlockButtonSection
            recoverySection
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showRecoveryKeyEntry)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: masterUnlockError)
    }

    // MARK: - Biometric Section

    @ViewBuilder
    private var biometricSection: some View {
        if biometricAvailable {
            biometricButton
            biometricDivider
        }
    }

    private var biometricButton: some View {
        Button {
            fvHaptic(.medium)
            Task { _ = await appLock.unlockWithBiometrics() }
        } label: {
            biometricButtonLabel
        }
        .buttonStyle(.plain)
        .shadow(color: FVColor.cyan.opacity(0.20), radius: 12, y: 4)
    }

    private var biometricButtonLabel: some View {
        HStack(spacing: 12) {
            biometricIconView
            Text("Continuer avec \(biometricLabel)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(FVGradient.cyanToViolet)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(biometricButtonBorder)
    }

    private var biometricIconView: some View {
        Image(systemName: biometricIcon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(.white.opacity(0.12))
            .clipShape(Circle())
    }

    private var biometricButtonBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
    }

    private var biometricDivider: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
            Text("ou")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.25))
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Password Field

    private var passwordFieldBorderColor: Color {
        if !masterUnlockError.isEmpty {
            return FVColor.danger.opacity(0.50)
        }
        return passwordFieldFocused
            ? FVColor.cyan.opacity(0.40)
            : Color.white.opacity(0.08)
    }

    private var passwordFieldSection: some View {
        HStack(spacing: 10) {
            passwordFieldIcon
            passwordFieldInput
            passwordToggleButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(passwordFieldBorder)
        .offset(x: shakeOffset)
    }

    private var passwordFieldIcon: some View {
        Image(systemName: "key.fill")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(FVColor.cyan.opacity(0.7))
            .frame(width: 16)
    }

    @ViewBuilder
    private var passwordFieldInput: some View {
        Group {
            if revealPassword {
                TextField("Mot de passe maître", text: $masterPassword)
            } else {
                SecureField("Mot de passe maître", text: $masterPassword)
            }
        }
        .focused($isPasswordFocused)
        .font(.system(size: 15, design: .rounded))
        .foregroundStyle(.white)
        .tint(FVColor.cyan)
        .onSubmit { attemptPasswordUnlock() }
    }

    private var passwordToggleButton: some View {
        Button {
            revealPassword.toggle()
            fvHaptic(.light)
        } label: {
            Image(systemName: revealPassword ? "eye.slash" : "eye")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.35))
        }
        .buttonStyle(.plain)
    }

    private var passwordFieldBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(
                passwordFieldBorderColor,
                lineWidth: passwordFieldFocused ? 1.5 : 1
            )
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        if !masterUnlockError.isEmpty {
            errorBanner
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var errorBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(FVColor.danger)
            Text(masterUnlockError)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.danger.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(FVColor.danger.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Unlock Button

    private var unlockButtonSection: some View {
        Button {
            fvHaptic(.medium)
            attemptPasswordUnlock()
        } label: {
            unlockButtonLabel
        }
        .buttonStyle(.plain)
    }

    private var unlockButtonLabel: some View {
        HStack(spacing: 7) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("Déverrouiller")
                .font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(unlockButtonBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: FVColor.cyan.opacity(0.18), radius: 12, y: 4)
    }

    private var unlockButtonBackground: some View {
        ZStack {
            FVGradient.cyanToViolet
            unlockButtonShimmer
        }
    }

    private var unlockButtonShimmer: some View {
        LinearGradient(
            colors: [.clear, .white.opacity(0.12), .clear],
            startPoint: UnitPoint(x: shimmerOffset, y: 0.5),
            endPoint: UnitPoint(x: shimmerOffset + 0.4, y: 0.5)
        )
    }

    // MARK: - Recovery Section

    @ViewBuilder
    private var recoverySection: some View {
        if showRecoveryKeyEntry {
            VStack(spacing: 10) {
                recoveryKeyField
                recoveryErrorView
                recoverySubmitButton
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var recoveryKeyField: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 13))
                .foregroundStyle(FVColor.violet.opacity(0.8))
                .frame(width: 16)
            TextField("Clé de récupération", text: $recoveryKeyInput)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white)
                .tint(FVColor.violet)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(recoveryKeyFieldBorder)
    }

    private var recoveryKeyFieldBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(FVColor.violet.opacity(0.30), lineWidth: 1)
    }

    @ViewBuilder
    private var recoveryErrorView: some View {
        if !recoveryKeyError.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(FVColor.danger)
                Text(recoveryKeyError)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.danger.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var recoverySubmitButton: some View {
        Button {
            fvHaptic(.medium)
            if authManager.unlockWithRecoveryKey(recoveryKeyInput) {
                fvHaptic(.success); appLock.forceUnlock()
            } else {
                fvHaptic(.error)
                withAnimation { recoveryKeyError = "Clé de récupération invalide." }
            }
        } label: {
            recoverySubmitLabel
        }
        .buttonStyle(.plain)
    }

    private var recoverySubmitLabel: some View {
        Text("Valider la clé de récupération")
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(FVColor.violet)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(FVColor.violet.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(FVColor.violet.opacity(0.25), lineWidth: 1)
            )
    }

    // MARK: - Footer Links

    private var footerLinks: some View {
        HStack(spacing: 16) {
            recoveryFooterButton
            Circle().fill(.white.opacity(0.15)).frame(width: 3, height: 3)
            logoutFooterButton
        }
    }

    private var recoveryFooterButton: some View {
        Button {
            fvHaptic(.light)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showRecoveryKeyEntry.toggle()
                recoveryKeyError = ""
            }
        } label: {
            Text(showRecoveryKeyEntry ? "Annuler" : "Clé de récupération")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.violet.opacity(0.50))
        }
        .buttonStyle(.plain)
    }

    private var logoutFooterButton: some View {
        Button {
            fvHaptic(.light)
            authManager.logout()
            appLock.forceUnlock()
        } label: {
            Text("Changer de compte")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.25))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Security Badge

    private var securityBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.15))
            Text("Powered by AES-256-GCM")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.15))
        }
    }

    // MARK: - Animations

    private func onAppearSetup() {
        detectBiometricType()
        startFloatAnimation()
        startGlowPulse()
        startPulseRing()
        startEntrance()
        startShimmer()
    }

    private func startFloatAnimation() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            lockFloat = -6
        }
    }

    private func startGlowPulse() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
    }

    private func startPulseRing() {
        withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
            pulseRing = true
        }
    }

    private func startEntrance() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.15)) {
            appeared = true
        }
    }

    private func startShimmer() {
        withAnimation(
            .linear(duration: 3.0)
            .repeatForever(autoreverses: false)
            .delay(1.0)
        ) {
            shimmerOffset = 1.6
        }
    }

    private func triggerShake() {
        withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) {
                shakeOffset = -8
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) {
                shakeOffset = 5
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
                shakeOffset = 0
            }
        }
    }

    // MARK: - Functions

    private func attemptPasswordUnlock() {
        if authManager.verifyMasterPasswordForVaultUnlock(masterPassword) {
            fvHaptic(.success)
            appLock.forceUnlock()
            masterPassword = ""
            masterUnlockError = ""
        } else {
            fvHaptic(.error)
            triggerShake()
            withAnimation(.spring(response: 0.3)) {
                masterUnlockError = String(localized: "lock.error.wrong_password")
            }
        }
    }

    private func detectBiometricType() {
        let context = LAContext()
        var error: NSError?
        biometricAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error
        )
        guard biometricAvailable else { return }
        switch context.biometryType {
        case .faceID:  biometricIcon = "faceid";  biometricLabel = "Face ID"
        case .touchID: biometricIcon = "touchid"; biometricLabel = "Touch ID"
        case .opticID: biometricIcon = "opticid"; biometricLabel = "Optic ID"
        default:       biometricIcon = "faceid";  biometricLabel = "biométrie"
        }
    }
}
