import SwiftUI
import LocalAuthentication

// MARK: - VaultLockView

struct VaultLockView: View {
    @ObservedObject var appLock: AppLockManager
    @ObservedObject var authManager: AuthManager

    @State private var masterPassword = ""
    @State private var masterUnlockError = ""
    @State private var showRecoveryKeyEntry = false
    @State private var recoveryKeyInput = ""
    @State private var recoveryKeyError = ""

    // Clock
    @State private var currentTime = Date()
    private let timeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Lock icon animations
    @State private var lockFloat: CGFloat = 0
    @State private var lockGlowPulse = false
    @State private var lockScanOffset: CGFloat = -50
    @State private var lockAppeared = false

    // Particle / orb animations
    @State private var orb1Offset: CGSize = .zero
    @State private var orb2Offset: CGSize = .zero
    @State private var orb3Offset: CGSize = .zero
    @State private var orb4Offset: CGSize = .zero
    @State private var orb1Scale: CGFloat = 1
    @State private var orb2Scale: CGFloat = 1
    @State private var particlePhase: CGFloat = 0

    // Biometric type
    @State private var biometricIcon = "faceid"
    @State private var biometricLabel = "Face ID"

    // Card entrance animation
    @State private var cardVisible = false

    // Biometric button press state
    @State private var biometricPressed = false

    // Time formatter
    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: currentTime)
    }
    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE d MMMM"
        f.locale = Locale(identifier: "fr_FR")
        return f.string(from: currentTime).capitalized
    }

    var body: some View {
        ZStack {
            // ── Background ───────────────────────────────────────────────
            FVAnimatedBackground()

            // Extra deep-cyan orbs layered on top of the shared background
            lockScreenOrbs

            // ── Content ──────────────────────────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // Time display
                    timeHeader
                        .fvAppear(delay: 0.1)

                    Spacer().frame(height: 28)

                    // Animated lock icon
                    lockHero
                        .fvAppear(delay: 0.2)

                    Spacer().frame(height: 28)

                    // Title + subtitle
                    titleBlock
                        .fvAppear(delay: 0.3)

                    Spacer().frame(height: 32)

                    // Biometric button
                    biometricButton
                        .fvAppear(delay: 0.4)

                    Spacer().frame(height: 20)

                    // Glass form card
                    formCard
                        .fvAppear(delay: 0.5)

                    Spacer().frame(height: 32)

                    // Back to login link
                    backToLoginLink
                        .fvAppear(delay: 0.65)

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
            }
        }
        .ignoresSafeArea()
        .onReceive(timeTimer) { _ in currentTime = Date() }
        .onAppear { startAllAnimations(); detectBiometricType() }
    }

    // MARK: - Subviews

    private var lockScreenOrbs: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [FVColor.cyan.opacity(0.13), .clear],
                    center: .center, startRadius: 10, endRadius: 220))
                .frame(width: 440, height: 440)
                .offset(orb1Offset)
                .scaleEffect(orb1Scale)
                .blur(radius: 38)

            Circle()
                .fill(RadialGradient(
                    colors: [FVColor.violet.opacity(0.11), .clear],
                    center: .center, startRadius: 10, endRadius: 260))
                .frame(width: 520, height: 520)
                .offset(orb2Offset)
                .scaleEffect(orb2Scale)
                .blur(radius: 50)

            Circle()
                .fill(RadialGradient(
                    colors: [FVColor.cyan.opacity(0.07), .clear],
                    center: .center, startRadius: 10, endRadius: 160))
                .frame(width: 320, height: 320)
                .offset(orb3Offset)
                .blur(radius: 30)

            Circle()
                .fill(RadialGradient(
                    colors: [FVColor.violet.opacity(0.09), .clear],
                    center: .center, startRadius: 10, endRadius: 140))
                .frame(width: 280, height: 280)
                .offset(orb4Offset)
                .blur(radius: 28)
        }
        .ignoresSafeArea()
    }

    private var timeHeader: some View {
        VStack(spacing: 4) {
            Text(timeString)
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .kerning(-2)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: timeString)

            Text(dateString)
                .font(FVFont.body(14))
                .foregroundStyle(FVColor.mist.opacity(0.6))
                .kerning(0.5)
        }
        .padding(.top, 52)
    }

    private var lockHero: some View {
        ZStack {
            // Outermost glow ring — slow pulse
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [FVColor.cyan.opacity(lockGlowPulse ? 0.55 : 0.18),
                                 FVColor.violet.opacity(lockGlowPulse ? 0.35 : 0.10),
                                 FVColor.cyan.opacity(lockGlowPulse ? 0.55 : 0.18)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(particlePhase * 60))
                .scaleEffect(lockGlowPulse ? 1.06 : 1.0)

            // Mid glow ring — filled, blurred
            Circle()
                .fill(RadialGradient(
                    colors: [FVColor.cyan.opacity(lockGlowPulse ? 0.22 : 0.10), .clear],
                    center: .center, startRadius: 30, endRadius: 80))
                .frame(width: 160, height: 160)
                .scaleEffect(lockGlowPulse ? 1.1 : 0.95)
                .blur(radius: 16)

            // Inner ring border
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [FVColor.cyan.opacity(0.6), FVColor.violet.opacity(0.4)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5
                )
                .frame(width: 108, height: 108)

            // Icon backing circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [FVColor.deepSlate.opacity(0.9), FVColor.abyss],
                        center: .center, startRadius: 10, endRadius: 52)
                )
                .frame(width: 100, height: 100)
                .shadow(color: FVColor.cyan.opacity(0.3), radius: 20)

            // Gradient lock icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FVColor.cyan, FVColor.cyanLight, FVColor.violet],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            // Scan line that sweeps across the icon
            scanLine
        }
        .frame(width: 160, height: 160)
        .offset(y: lockFloat)
    }

    private var scanLine: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [.clear, FVColor.cyan.opacity(0.55), .clear],
                    startPoint: .leading, endPoint: .trailing)
            )
            .frame(width: 80, height: 2)
            .offset(y: lockScanOffset)
            .clipShape(Circle().scale(1.3))
            .blendMode(.screen)
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("COFFRE VERROUILLÉ")
                .font(FVFont.display(22))
                .kerning(4)
                .foregroundStyle(
                    LinearGradient(
                        colors: [FVColor.cyan, FVColor.cyanLight],
                        startPoint: .leading, endPoint: .trailing)
                )

            Text("Vault locked for your security")
                .font(FVFont.body(13))
                .foregroundStyle(FVColor.mist.opacity(0.65))
                .kerning(0.3)
        }
    }

    private var biometricButton: some View {
        Button {
            fvHaptic(.medium)
            biometricPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                biometricPressed = false
            }
            Task { _ = await appLock.unlockWithBiometrics() }
        } label: {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(FVGradient.cyanToViolet)

                // Shimmer overlay
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.12), .clear, .white.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                // Border
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)

                HStack(spacing: 16) {
                    Image(systemName: biometricIcon)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: FVColor.cyan.opacity(0.5), radius: 10)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(biometricLabel)
                            .font(FVFont.label(17))
                            .foregroundStyle(.white)
                        Text(String(localized: "lock.button.biometric"))
                            .font(FVFont.body(12))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
        }
        .buttonStyle(.plain)
        .shadow(color: FVColor.cyan.opacity(0.35), radius: 24, y: 8)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .scaleEffect(biometricPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: biometricPressed)
    }

    private var formCard: some View {
        VStack(spacing: 0) {

            // Error banner (lock-level)
            if !appLock.lockError.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(FVColor.danger)
                    Text(appLock.lockError)
                        .font(FVFont.body(13))
                        .foregroundStyle(FVColor.danger.opacity(0.9))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FVColor.danger.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(FVColor.danger.opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.bottom, 18)
            }

            // Divider label
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                Text("OU MOT DE PASSE")
                    .font(FVFont.caption(10))
                    .kerning(2)
                    .foregroundStyle(FVColor.smoke)
                    .fixedSize()
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
            }
            .padding(.bottom, 18)

            // Master password field
            FVTextField(
                title: String(localized: "lock.field.master_password"),
                text: $masterPassword,
                secure: true,
                icon: "key.fill"
            )

            if !masterUnlockError.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(FVColor.danger)
                    Text(masterUnlockError)
                        .font(FVFont.caption(12))
                        .foregroundStyle(FVColor.danger.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer().frame(height: 14)

            FVButton(
                title: String(localized: "lock.button.password"),
                icon: "lock.open.fill"
            ) {
                fvHaptic(.medium)
                if authManager.verifyMasterPasswordForVaultUnlock(masterPassword) {
                    fvHaptic(.success)
                    appLock.forceUnlock()
                    masterPassword = ""
                    masterUnlockError = ""
                } else {
                    fvHaptic(.error)
                    withAnimation(.spring(response: 0.3)) {
                        masterUnlockError = String(localized: "lock.error.wrong_password")
                    }
                }
            }

            // Recovery section
            VStack(spacing: 14) {
                if showRecoveryKeyEntry {
                    Spacer().frame(height: 4)

                    // Recovery divider
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(FVColor.violet.opacity(0.18))
                            .frame(height: 1)
                        Text("CLÉ DE RÉCUPÉRATION")
                            .font(FVFont.caption(10))
                            .kerning(2)
                            .foregroundStyle(FVColor.violet.opacity(0.7))
                            .fixedSize()
                        Rectangle()
                            .fill(FVColor.violet.opacity(0.18))
                            .frame(height: 1)
                    }

                    FVTextField(
                        title: String(localized: "lock.field.recovery_key"),
                        text: $recoveryKeyInput,
                        icon: "key.horizontal.fill"
                    )

                    if !recoveryKeyError.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(FVColor.danger)
                            Text(recoveryKeyError)
                                .font(FVFont.caption(12))
                                .foregroundStyle(FVColor.danger.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    FVButton(
                        title: String(localized: "lock.button.recovery"),
                        icon: "checkmark.shield.fill",
                        style: .secondary
                    ) {
                        fvHaptic(.medium)
                        if authManager.unlockWithRecoveryKey(recoveryKeyInput) {
                            fvHaptic(.success)
                            appLock.forceUnlock()
                            recoveryKeyInput = ""
                            recoveryKeyError = ""
                        } else {
                            fvHaptic(.error)
                            withAnimation(.spring(response: 0.3)) {
                                recoveryKeyError = String(localized: "lock.error.invalid_recovery")
                            }
                        }
                    }
                }

                // Toggle recovery key entry
                Button {
                    fvHaptic(.light)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showRecoveryKeyEntry.toggle()
                        recoveryKeyError = ""
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showRecoveryKeyEntry
                              ? "xmark.circle.fill"
                              : "key.horizontal.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(showRecoveryKeyEntry
                             ? String(localized: "lock.button.cancel_recovery")
                             : String(localized: "lock.button.use_recovery"))
                            .font(FVFont.body(13))
                    }
                    .foregroundStyle(FVColor.violet.opacity(0.85))
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.35))
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(FVGradient.cardGlass)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            FVColor.cyan.opacity(0.28),
                            Color.white.opacity(0.06),
                            FVColor.violet.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: FVColor.cyan.opacity(0.12), radius: 28, y: 8)
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }

    private var backToLoginLink: some View {
        Button {
            fvHaptic(.light)
            authManager.logout()
            appLock.forceUnlock()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 11, weight: .semibold))
                Text(String(localized: "lock.button.back_to_login"))
                    .font(FVFont.body(13))
            }
            .foregroundStyle(FVColor.mist.opacity(0.55))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Animation Setup

    private func startAllAnimations() {
        // Floating lock icon
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            lockFloat = -10
        }

        // Pulsing glow ring
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            lockGlowPulse = true
        }

        // Scan line sweep
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
            lockScanOffset = 50
        }

        // Particle / dashed ring rotation
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            particlePhase = 1
        }

        // Orb drifts
        withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
            orb1Offset = CGSize(width: 60, height: -100)
            orb1Scale = 1.15
        }
        withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
            orb2Offset = CGSize(width: -80, height: 90)
            orb2Scale = 0.88
        }
        withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
            orb3Offset = CGSize(width: 100, height: 110)
        }
        withAnimation(.easeInOut(duration: 13).repeatForever(autoreverses: true)) {
            orb4Offset = CGSize(width: -110, height: -60)
        }
    }

    private func detectBiometricType() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return }
        switch context.biometryType {
        case .faceID:
            biometricIcon = "faceid"
            biometricLabel = "Face ID"
        case .touchID:
            biometricIcon = "touchid"
            biometricLabel = "Touch ID"
        case .opticID:
            biometricIcon = "opticid"
            biometricLabel = "Optic ID"
        default:
            biometricIcon = "faceid"
            biometricLabel = "Biométrie"
        }
    }
}
