import SwiftUI

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - AuthView — Ultra Premium $50M Design
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

    // MARK: - Animation State
    @State private var shieldPulse = false
    @State private var shieldRotation: Double = 0
    @State private var gradientPhase: Double = 0
    @State private var cardBorderRotation: Double = 0
    @State private var shimmerOffset: CGFloat = -400
    @State private var errorShake = false
    @State private var errorGlow = false
    @State private var isLoading = false
    @State private var titleGradientPhase: Double = 0
    @State private var heroAppeared = false
    @State private var formAppeared = false

    // Floating particles
    @State private var particle1Offset: CGSize = CGSize(width: -60, height: 20)
    @State private var particle2Offset: CGSize = CGSize(width: 70, height: -30)
    @State private var particle3Offset: CGSize = CGSize(width: -30, height: -60)
    @State private var particle4Offset: CGSize = CGSize(width: 50, height: 55)
    @State private var particleOpacity1: Double = 0.4
    @State private var particleOpacity2: Double = 0.3
    @State private var particleOpacity3: Double = 0.5
    @State private var particleOpacity4: Double = 0.25

    // Glow ring animation
    @State private var glowRing1Scale: CGFloat = 1.0
    @State private var glowRing2Scale: CGFloat = 1.0
    @State private var glowRing3Scale: CGFloat = 1.0
    @State private var glowRing1Opacity: Double = 0.6
    @State private var glowRing2Opacity: Double = 0.4
    @State private var glowRing3Opacity: Double = 0.2

    // MARK: - Mode Enum

    enum AuthMode: String, CaseIterable, Identifiable {
        case login = "Connexion"
        case register = "Inscription"
        var id: String { rawValue }
        var localizedName: String {
            switch self {
            case .login:    return String(localized: "auth.mode.login")
            case .register: return String(localized: "auth.mode.register")
            }
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 0 — Animated background
                FVAnimatedBackground()
                    .ignoresSafeArea()

                // Layer 1 — Floating particles
                floatingParticles(in: geo)

                // Layer 2 — Main scroll content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // TOP 40% — Hero
                        heroSection(height: geo.size.height * 0.42)

                        // BOTTOM 60% — Glass card form
                        formSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .animation(.easeInOut(duration: 0.35), value: mode)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: showRecoveryEntry)
        .animation(.easeInOut(duration: 0.25), value: password.isEmpty)
        .onAppear { startAllAnimations() }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Hero Section (top 40%)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func heroSection(height: CGFloat) -> some View {
        ZStack {
            // Deep radial gradient fade for hero depth
            RadialGradient(
                colors: [
                    FVColor.cyan.opacity(0.12),
                    FVColor.violet.opacity(0.08),
                    .clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 240
            )
            .blendMode(.screen)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Animated shield logo
                shieldLogo
                    .opacity(heroAppeared ? 1 : 0)
                    .scaleEffect(heroAppeared ? 1 : 0.6)
                    .animation(.spring(response: 0.8, dampingFraction: 0.65).delay(0.1), value: heroAppeared)

                Spacer().frame(height: 20)

                // FYXXVAULT title with animated gradient
                heroTitle
                    .opacity(heroAppeared ? 1 : 0)
                    .offset(y: heroAppeared ? 0 : 18)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.25), value: heroAppeared)

                Spacer().frame(height: 8)

                // Tagline
                Text("Le coffre ultime")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.mist.opacity(0.7))
                    .kerning(1.5)
                    .opacity(heroAppeared ? 1 : 0)
                    .offset(y: heroAppeared ? 0 : 12)
                    .animation(.spring(response: 0.6).delay(0.38), value: heroAppeared)

                Spacer().frame(height: 20)

                // Feature tags row
                featureTagRow
                    .opacity(heroAppeared ? 1 : 0)
                    .offset(y: heroAppeared ? 0 : 14)
                    .animation(.spring(response: 0.5).delay(0.52), value: heroAppeared)

                Spacer(minLength: 0)
            }
            .padding(.top, 60)
            .padding(.bottom, 16)
        }
        .frame(height: height)
    }

    // MARK: Shield Logo

    private var shieldLogo: some View {
        ZStack {
            // Outermost pulsing atmospheric glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [FVColor.cyan.opacity(0.18), FVColor.violet.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
                .scaleEffect(glowRing3Scale)
                .opacity(glowRing3Opacity)
                .blur(radius: 8)

            // Glow ring 2
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            FVColor.cyan.opacity(0.0),
                            FVColor.cyan.opacity(0.25),
                            FVColor.violet.opacity(0.3),
                            FVColor.gold.opacity(0.2),
                            FVColor.cyan.opacity(0.0)
                        ],
                        center: .center
                    ),
                    lineWidth: 1.2
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(cardBorderRotation * 1.3))
                .scaleEffect(glowRing2Scale)
                .opacity(glowRing2Opacity)

            // Glow ring 1 — close pulsing
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [FVColor.cyan.opacity(0.35), FVColor.violet.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 108, height: 108)
                .scaleEffect(glowRing1Scale)
                .opacity(glowRing1Opacity)

            // Rotating gradient ring (outer border of the logo circle)
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            FVColor.cyan,
                            FVColor.violet,
                            FVColor.gold,
                            FVColor.cyan
                        ],
                        center: .center
                    ),
                    lineWidth: 2.5
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(cardBorderRotation))
                .shadow(color: FVColor.cyan.opacity(0.4), radius: 6)

            // Main logo circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [FVColor.cyan.opacity(0.25), FVColor.violet.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial.opacity(0.5))
                        .frame(width: 80, height: 80)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: FVColor.cyan.opacity(0.45), radius: 28, y: 6)
                .shadow(color: FVColor.violet.opacity(0.2), radius: 16, y: 4)

            // Shield icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, FVColor.cyanLight.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: FVColor.cyan.opacity(0.5), radius: 12)
                .scaleEffect(shieldPulse ? 1.04 : 0.98)
        }
    }

    // MARK: Animated Gradient Title

    private var heroTitle: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { _ in
            Text("FYXXVAULT")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .kerning(6)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            FVColor.cyan,
                            FVColor.violetLight,
                            FVColor.gold,
                            FVColor.cyan
                        ],
                        startPoint: UnitPoint(
                            x: 0 + cos(titleGradientPhase) * 0.5,
                            y: 0
                        ),
                        endPoint: UnitPoint(
                            x: 1 + sin(titleGradientPhase) * 0.3,
                            y: 1
                        )
                    )
                )
                .shadow(color: FVColor.cyan.opacity(0.3), radius: 18, y: 4)
        }
    }

    // MARK: Feature Tag Row

    private var featureTagRow: some View {
        HStack(spacing: 10) {
            FVFloatingTag(text: "AES-256", color: FVColor.cyan, delay: 0.0)
            FVFloatingTag(text: "Zero-Knowledge", color: FVColor.violet, delay: 0.15)
            FVFloatingTag(text: "MFA", color: FVColor.gold, delay: 0.3)
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Floating Particles
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func floatingParticles(in geo: GeometryProxy) -> some View {
        ZStack {
            // Particle 1 — cyan
            Circle()
                .fill(FVColor.cyan.opacity(particleOpacity1))
                .frame(width: 6, height: 6)
                .blur(radius: 1)
                .offset(
                    x: geo.size.width * 0.15 + particle1Offset.width,
                    y: geo.size.height * 0.28 + particle1Offset.height
                )

            // Particle 2 — violet
            Circle()
                .fill(FVColor.violet.opacity(particleOpacity2))
                .frame(width: 4, height: 4)
                .blur(radius: 0.8)
                .offset(
                    x: geo.size.width * 0.82 + particle2Offset.width,
                    y: geo.size.height * 0.18 + particle2Offset.height
                )

            // Particle 3 — gold
            Circle()
                .fill(FVColor.gold.opacity(particleOpacity3))
                .frame(width: 5, height: 5)
                .blur(radius: 1)
                .offset(
                    x: geo.size.width * 0.72 + particle3Offset.width,
                    y: geo.size.height * 0.35 + particle3Offset.height
                )

            // Particle 4 — cyan small
            Circle()
                .fill(FVColor.cyanLight.opacity(particleOpacity4))
                .frame(width: 3, height: 3)
                .offset(
                    x: geo.size.width * 0.25 + particle4Offset.width,
                    y: geo.size.height * 0.42 + particle4Offset.height
                )
        }
        .ignoresSafeArea()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Form Section (bottom 60%)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var formSection: some View {
        ZStack {
            // Animated rotating gradient card border
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    AngularGradient(
                        colors: [
                            FVColor.cyan.opacity(0.5),
                            FVColor.violet.opacity(0.4),
                            FVColor.gold.opacity(0.3),
                            FVColor.cyan.opacity(0.1),
                            FVColor.violet.opacity(0.5),
                            FVColor.cyan.opacity(0.5)
                        ],
                        center: .center,
                        startAngle: .degrees(cardBorderRotation),
                        endAngle: .degrees(cardBorderRotation + 360)
                    ),
                    lineWidth: 1.5
                )
                .blur(radius: 1.5)
                .padding(1)

            // Glass card content
            VStack(spacing: 22) {
                // Premium tab selector
                premiumTabSelector
                    .fvAppear(delay: 0.1)

                // Email field
                FVTextField(
                    title: String(localized: "auth.field.email"),
                    text: $email,
                    keyboard: .email,
                    contentType: .email
                )
                .fvAppear(delay: 0.18)

                // Password field
                FVTextField(
                    title: String(localized: "auth.field.master_password"),
                    text: $password,
                    secure: true,
                    contentType: .password
                )
                .fvAppear(delay: 0.24)

                // Register-only fields
                registerFields

                // Error message
                errorMessage

                // Submit button
                submitButton
                    .fvAppear(delay: 0.38)

                // Recovery section (login only)
                loginRecoverySection
            }
            .padding(24)
            .background(
                ZStack {
                    // Deep glass base
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.35))

                    // Subtle inner gradient
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.07),
                                    FVColor.violet.opacity(0.03),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: FVColor.cyan.opacity(0.08), radius: 30, y: 12)
            .shadow(color: FVColor.violet.opacity(0.06), radius: 24, y: 8)
            .shadow(color: .black.opacity(0.35), radius: 40, y: 20)
        }
        .opacity(formAppeared ? 1 : 0)
        .offset(y: formAppeared ? 0 : 30)
        .animation(.spring(response: 0.75, dampingFraction: 0.78).delay(0.3), value: formAppeared)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Premium Tab Selector
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var premiumTabSelector: some View {
        ZStack(alignment: .leading) {
            // Container track
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                )

            // Animated sliding indicator
            GeometryReader { geo in
                let halfW = geo.size.width / 2
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                FVColor.cyan.opacity(0.85),
                                FVColor.violet.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: FVColor.cyan.opacity(0.35), radius: 12, y: 3)
                    .shadow(color: FVColor.violet.opacity(0.2), radius: 8, y: 2)
                    .frame(width: halfW - 8)
                    .offset(x: mode == .login ? 4 : halfW + 4)
                    .animation(.spring(response: 0.38, dampingFraction: 0.78), value: mode)
            }

            // Tab buttons overlay
            HStack(spacing: 0) {
                ForEach(AuthMode.allCases) { m in
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                            mode = m
                        }
                        fvHaptic(.light)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: m == .login ? "lock.fill" : "person.badge.plus")
                                .font(.system(size: 12, weight: .bold))
                            Text(m.localizedName)
                                .font(FVFont.label(13))
                        }
                        .foregroundStyle(mode == m ? .white : FVColor.smoke)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 46)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Register-only Fields
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @ViewBuilder
    private var registerFields: some View {
        if mode == .register {
            // Password strength requirements
            if !password.isEmpty {
                passwordRequirementsCard
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.96, anchor: .top)),
                        removal:   .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                    ))
            }

            FVTextField(
                title: String(localized: "auth.field.confirm_password"),
                text: $confirmPassword,
                secure: true,
                contentType: .password
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal:   .opacity
            ))

            // Panic password field + warning
            VStack(alignment: .leading, spacing: 6) {
                FVTextField(
                    title: String(localized: "auth.field.panic_password"),
                    text: $panicPassword,
                    secure: true
                )

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
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal:   .opacity
            ))
        }
    }

    // MARK: Password Requirements Card

    private var passwordRequirementsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "lock.badge.clock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FVColor.cyan.opacity(0.8))
                Text(String(localized: "auth.password.requirements.title"))
                    .font(FVFont.caption(11))
                    .foregroundStyle(FVColor.smoke)
                    .kerning(0.8)

                Spacer()

                // Mini strength indicator
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < passwordStrengthLevel ? strengthColor : Color.white.opacity(0.08))
                            .frame(width: 18, height: 4)
                            .animation(.spring(response: 0.3), value: passwordStrengthLevel)
                    }
                }
            }

            // Requirements grid (2 columns)
            VStack(spacing: 5) {
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
        }
        .padding(14)
        .background(
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
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(strengthColor.opacity(0.18), lineWidth: 1)
                .animation(.easeOut(duration: 0.3), value: passwordStrengthLevel)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: password)
    }

    private var passwordStrengthLevel: Int {
        var score = 0
        if password.count >= 12                                                                     { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil                               { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil                                  { score += 1 }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:,.<>?/\\\"'`~")) != nil { score += 1 }
        return score
    }

    private var strengthColor: Color {
        switch passwordStrengthLevel {
        case 0, 1: return FVColor.danger
        case 2:    return FVColor.warning
        case 3:    return FVColor.cyan
        default:   return FVColor.success
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Error Message
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @ViewBuilder
    private var errorMessage: some View {
        if !authManager.authError.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FVColor.danger)

                Text(authManager.authError)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(FVColor.danger.opacity(0.08))
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(FVColor.danger.opacity(errorGlow ? 0.14 : 0.05))
                    .animation(
                        .easeInOut(duration: 0.35).repeatCount(3, autoreverses: true),
                        value: errorGlow
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(FVColor.danger.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: FVColor.danger.opacity(errorGlow ? 0.3 : 0.1), radius: 12, y: 4)
            .offset(x: errorShake ? -7 : 0)
            .animation(
                .spring(response: 0.08, dampingFraction: 0.25).repeatCount(5, autoreverses: true),
                value: errorShake
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)),
                removal:   .opacity.combined(with: .scale(scale: 0.95))
            ))
            .onChange(of: authManager.authError) { _, newValue in
                guard !newValue.isEmpty else { return }
                errorShake = false
                errorGlow  = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    errorShake = true
                    errorGlow  = true
                    fvHaptic(.error)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    errorShake = false
                    errorGlow  = false
                }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Submit Button
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var submitButton: some View {
        Button {
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
        } label: {
            ZStack {
                // Gradient fill
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [FVColor.cyan, FVColor.violet, FVColor.violet.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Shimmer sweep
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.22), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset)
                    .clipped()

                // Glow border
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.2)

                // Content
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: mode == .login ? "lock.open.fill" : "sparkles")
                            .font(.system(size: 16, weight: .bold))
                        Text(mode == .login
                             ? String(localized: "auth.button.login")
                             : String(localized: "auth.button.register"))
                        .font(FVFont.label(16))
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: FVColor.cyan.opacity(0.38), radius: 22, y: 8)
            .shadow(color: FVColor.violet.opacity(0.22), radius: 14, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .scaleEffect(isLoading ? 0.98 : 1)
        .animation(.spring(response: 0.3), value: isLoading)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Recovery Section
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @ViewBuilder
    private var loginRecoverySection: some View {
        if mode == .login {
            // Elegant OU divider
            HStack(spacing: 14) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.1)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 1)

                Text(String(localized: "auth.divider.or"))
                    .font(FVFont.caption(10))
                    .foregroundStyle(FVColor.smoke.opacity(0.7))
                    .kerning(2)
                    .padding(.horizontal, 4)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }

            // Forgot password toggle
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    showRecoveryEntry.toggle()
                    recoveryError = ""
                }
                fvHaptic(.light)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showRecoveryEntry ? "xmark.circle" : "key.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(showRecoveryEntry
                         ? String(localized: "auth.recovery.cancel")
                         : String(localized: "auth.recovery.forgot_password"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [FVColor.violet, FVColor.violetLight],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            }
            .buttonStyle(.plain)

            // Recovery form
            if showRecoveryEntry {
                recoveryForm
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.97, anchor: .top)),
                        removal:   .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
                    ))
            }

            // Version footer
            versionFooter
        }
    }

    // MARK: Recovery Form

    private var recoveryForm: some View {
        VStack(spacing: 14) {
            FVTextField(
                title: String(localized: "auth.recovery.field.key"),
                text: $recoveryKeyInput,
                icon: "key.horizontal.fill"
            )

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

            FVButton(title: String(localized: "auth.recovery.button.unlock"), icon: "lock.open.rotation", style: .secondary) {
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
        .padding(16)
        .background(FVColor.abyss.opacity(0.4))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(FVColor.violet.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Version Footer

    private var versionFooter: some View {
        Text("v1.0 • Zero-Knowledge • Open Source")
            .font(FVFont.caption(10))
            .foregroundStyle(FVColor.smoke.opacity(0.35))
            .kerning(0.8)
            .padding(.top, 4)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Animation Engine
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startAllAnimations() {
        // Hero / form appear
        heroAppeared = true
        formAppeared = true

        // Shield pulse (slow, breathing)
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            shieldPulse = true
        }

        // Continuous rotating gradient border
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            cardBorderRotation = 360
        }

        // Title gradient phase
        withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
            titleGradientPhase = .pi * 2
        }

        // Submit button shimmer
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: false)) {
            shimmerOffset = 400
        }

        // Glow rings
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            glowRing1Scale   = 1.08
            glowRing1Opacity = 0.5
        }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(0.4)) {
            glowRing2Scale   = 1.12
            glowRing2Opacity = 0.3
        }
        withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true).delay(0.8)) {
            glowRing3Scale   = 1.06
            glowRing3Opacity = 0.15
        }

        // Floating particles — independent motions
        withAnimation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true)) {
            particle1Offset = CGSize(width: -80, height: -40)
            particleOpacity1 = 0.65
        }
        withAnimation(.easeInOut(duration: 4.4).repeatForever(autoreverses: true).delay(0.7)) {
            particle2Offset = CGSize(width: 40, height: 30)
            particleOpacity2 = 0.5
        }
        withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true).delay(1.1)) {
            particle3Offset = CGSize(width: -55, height: 20)
            particleOpacity3 = 0.35
        }
        withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true).delay(0.3)) {
            particle4Offset = CGSize(width: 70, height: -50)
            particleOpacity4 = 0.45
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - FVFloatingTag — Animated Feature Badge
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct FVFloatingTag: View {
    let text: String
    let color: Color
    let delay: Double

    @State private var floatOffset: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .shadow(color: color.opacity(0.8), radius: 4)
            Text(text)
                .font(FVFont.caption(10))
                .foregroundStyle(color)
                .kerning(0.6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .background(.ultraThinMaterial.opacity(0.3))
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.28), lineWidth: 1)
        )
        .clipShape(Capsule())
        .shadow(color: color.opacity(0.2), radius: 8, y: 2)
        .offset(y: floatOffset)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.7)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(delay)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2.8 + delay * 0.6).repeatForever(autoreverses: true).delay(delay)) {
                floatOffset = -5
            }
        }
    }
}
