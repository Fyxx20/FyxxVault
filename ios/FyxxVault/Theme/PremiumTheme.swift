import SwiftUI
import Combine

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - FyxxVault Ultra Premium Design System
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// MARK: - Color Palette

enum FVColor {
    // Backgrounds
    static let abyss       = Color(red: 10/255, green: 16/255, blue: 30/255)
    static let obsidian    = Color(red: 16/255, green: 24/255, blue: 42/255)
    static let void_       = Color(red: 22/255, green: 30/255, blue: 50/255)
    static let carbon      = Color(red: 26/255, green: 34/255, blue: 58/255)
    static let deepSlate   = Color(red: 30/255, green: 40/255, blue: 66/255)
    static let nightPurple = Color(red: 40/255, green: 34/255, blue: 78/255)

    // Accent Primary — Electric Cyan
    static let cyan        = Color(red: 0/255, green: 212/255, blue: 255/255)
    static let cyanLight   = Color(red: 120/255, green: 235/255, blue: 255/255)
    static let cyanGlow    = Color(red: 0/255, green: 212/255, blue: 255/255).opacity(0.4)

    // Accent Secondary — Violet
    static let violet      = Color(red: 138/255, green: 92/255, blue: 246/255)
    static let violetLight = Color(red: 172/255, green: 140/255, blue: 255/255)
    static let violetGlow  = Color(red: 138/255, green: 92/255, blue: 246/255).opacity(0.35)

    // Accent Tertiary — Gold Premium
    static let gold        = Color(red: 255/255, green: 200/255, blue: 55/255)
    static let goldLight   = Color(red: 255/255, green: 225/255, blue: 130/255)

    // Accent Quaternary — Rose/Magenta
    static let rose        = Color(red: 255/255, green: 55/255, blue: 130/255)

    // Neutrals
    static let silver      = Color(red: 220/255, green: 228/255, blue: 240/255)
    static let mist        = Color(red: 180/255, green: 195/255, blue: 215/255)
    static let smoke       = Color(red: 120/255, green: 138/255, blue: 160/255)
    static let ash         = Color(red: 70/255, green: 82/255, blue: 100/255)

    // Card surfaces
    static let cardBg      = Color.white.opacity(0.04)
    static let cardBorder  = Color.white.opacity(0.08)
    static let cardHover   = Color.white.opacity(0.07)

    // Semantic
    static let success     = Color(red: 52/255, green: 211/255, blue: 153/255)
    static let warning     = Color(red: 251/255, green: 191/255, blue: 36/255)
    static let danger      = Color(red: 239/255, green: 68/255, blue: 68/255)
}

// MARK: - Premium Gradients

enum FVGradient {
    static let cyanToViolet = LinearGradient(
        colors: [FVColor.cyan, FVColor.violet],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let violetToRose = LinearGradient(
        colors: [FVColor.violet, FVColor.rose],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let cyanToGold = LinearGradient(
        colors: [FVColor.cyan, FVColor.gold],
        startPoint: .leading, endPoint: .trailing
    )
    static let goldShimmer = LinearGradient(
        colors: [FVColor.gold.opacity(0.8), FVColor.goldLight, FVColor.gold.opacity(0.8)],
        startPoint: .leading, endPoint: .trailing
    )
    static let darkFade = LinearGradient(
        colors: [FVColor.obsidian, FVColor.void_, FVColor.deepSlate, FVColor.nightPurple],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let cardGlass = LinearGradient(
        colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Typography

enum FVFont {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func heading(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .rounded) }
    static func caption(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .rounded) }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
    static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
}

// MARK: - Animated Premium Background

struct FVAnimatedBackground: View {
    @State private var phase: CGFloat = 0
    @State private var orbOffset1: CGSize = .zero
    @State private var orbOffset2: CGSize = .zero
    @State private var orbOffset3: CGSize = .zero
    private var meshCenterX: Float { 0.5 + Float(sin(phase)) * 0.1 }
    private var meshCenterY: Float { 0.5 + Float(cos(phase)) * 0.1 }
    private var meshPoints: [SIMD2<Float>] {
        [
            .init(x: 0, y: 0), .init(x: 0.5, y: 0), .init(x: 1, y: 0),
            .init(x: 0, y: 0.5), .init(x: meshCenterX, y: meshCenterY), .init(x: 1, y: 0.5),
            .init(x: 0, y: 1), .init(x: 0.5, y: 1), .init(x: 1, y: 1)
        ]
    }
    private let meshColors: [Color] = [
        FVColor.abyss, FVColor.obsidian, FVColor.nightPurple,
        FVColor.obsidian, FVColor.deepSlate, FVColor.void_,
        FVColor.abyss, FVColor.nightPurple.opacity(0.6), FVColor.abyss
    ]

    var body: some View {
        ZStack {
            // Base gradient
            FVGradient.darkFade.ignoresSafeArea()

            // Mesh gradient layer (iOS 18+)
            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3, height: 3,
                    points: meshPoints,
                    colors: meshColors
                )
                .opacity(0.7)
                .blendMode(.screen)
                .ignoresSafeArea()
            }

            // Floating orbs
            Circle()
                .fill(RadialGradient(colors: [FVColor.cyan.opacity(0.18), .clear], center: .center, startRadius: 10, endRadius: 200))
                .frame(width: 400, height: 400)
                .offset(orbOffset1)
                .blur(radius: 40)

            Circle()
                .fill(RadialGradient(colors: [FVColor.violet.opacity(0.14), .clear], center: .center, startRadius: 10, endRadius: 240))
                .frame(width: 450, height: 450)
                .offset(orbOffset2)
                .blur(radius: 50)

            Circle()
                .fill(RadialGradient(colors: [FVColor.rose.opacity(0.08), .clear], center: .center, startRadius: 10, endRadius: 180))
                .frame(width: 300, height: 300)
                .offset(orbOffset3)
                .blur(radius: 35)

            // Noise texture overlay
            Color.white.opacity(0.012).blendMode(.overlay).ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                phase = .pi * 2
                orbOffset1 = CGSize(width: 80, height: -120)
                orbOffset2 = CGSize(width: -100, height: 80)
                orbOffset3 = CGSize(width: 60, height: 100)
            }
        }
    }
}

// MARK: - Glass Card

struct FVGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 20
    var borderOpacity: Double = 0.12
    var shadowRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.45))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(FVGradient.cardGlass.opacity(0.9))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(borderOpacity), Color.white.opacity(borderOpacity * 0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: FVColor.cyan.opacity(0.08), radius: shadowRadius, y: 8)
            .shadow(color: .black.opacity(0.2), radius: shadowRadius, y: 10)
    }
}

// MARK: - Glowing Glass Card (for emphasis)

struct FVGlowCard: ViewModifier {
    var color: Color = FVColor.cyan
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.25))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(color.opacity(0.03))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [color.opacity(0.35), color.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: color.opacity(0.12), radius: 20, y: 8)
            .shadow(color: .black.opacity(0.25), radius: 16, y: 10)
    }
}

// MARK: - View Extensions

extension View {
    func fvGlass(cornerRadius: CGFloat = 24, padding: CGFloat = 20) -> some View {
        modifier(FVGlassCard(cornerRadius: cornerRadius, padding: padding))
    }

    func fvGlow(_ color: Color = FVColor.cyan, cornerRadius: CGFloat = 24) -> some View {
        modifier(FVGlowCard(color: color, cornerRadius: cornerRadius))
    }

    @ViewBuilder func fvPlatformTextEntry() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder func fvPlatformPageTab() -> some View {
        #if os(iOS)
        self.tabViewStyle(.page(indexDisplayMode: .always))
        #else
        self
        #endif
    }

    @ViewBuilder func fvInlineNavTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder func fvKeyboard(_ type: FVKeyboardType) -> some View {
        #if os(iOS)
        switch type {
        case .normal:      self.keyboardType(.default)
        case .email:       self.keyboardType(.emailAddress)
        case .number:      self.keyboardType(.numberPad)
        }
        #else
        self
        #endif
    }

    @ViewBuilder func fvContentType(_ type: FVContentType) -> some View {
        #if os(iOS)
        switch type {
        case .none:     self
        case .email:    self.textContentType(.emailAddress)
        case .username: self.textContentType(.username)
        case .password: self.textContentType(.password)
        }
        #else
        self
        #endif
    }
}

enum FVKeyboardType { case normal, email, number }
enum FVContentType { case none, email, username, password }

// MARK: - Premium Primary Button

struct FVButton: View {
    let title: String
    var icon: String? = nil
    var style: Style = .primary
    var action: () -> Void

    enum Style {
        case primary, secondary, danger, gold
    }

    @State private var isPressed = false
    @State private var shimmerOffset: CGFloat = -200

    private var gradient: LinearGradient {
        switch style {
        case .primary:   return FVGradient.cyanToViolet
        case .secondary: return LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
        case .danger:    return LinearGradient(colors: [FVColor.danger.opacity(0.8), FVColor.rose.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
        case .gold:      return FVGradient.goldShimmer
        }
    }

    private var textColor: Color {
        switch style {
        case .primary:   return .white
        case .secondary: return FVColor.silver
        case .danger:    return .white
        case .gold:      return FVColor.abyss
        }
    }

    var body: some View {
        Button(action: {
            fvHaptic(.medium)
            action()
        }) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                }
                Text(title)
                    .font(FVFont.label(15))
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                // Shimmer effect
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(style == .primary ? 0.15 : 0.05), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset)
                    .mask(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(style == .primary ? 0.2 : 0.08), lineWidth: 1)
            )
            .shadow(color: style == .primary ? FVColor.cyan.opacity(0.25) : .clear, radius: 16, y: 6)
            .scaleEffect(isPressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 400
            }
        }
        .pressEvents {
            withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
        } onRelease: {
            withAnimation(.spring(response: 0.3)) { isPressed = false }
        }
    }
}

// MARK: - Press Events Helper

struct PressEventsModifier: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Premium Text Field

struct FVTextField: View {
    let title: String
    @Binding var text: String
    var secure: Bool = false
    var icon: String? = nil
    var keyboard: FVKeyboardType = .normal
    var contentType: FVContentType = .none

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(FVFont.caption(12))
                .foregroundStyle(isFocused ? FVColor.cyan : FVColor.smoke)
                .animation(.easeOut(duration: 0.2), value: isFocused)

            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isFocused ? FVColor.cyan : FVColor.ash)
                        .frame(width: 20)
                }
                Group {
                    if secure {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                    }
                }
                .fvPlatformTextEntry()
                .fvKeyboard(keyboard)
                .fvContentType(contentType)
                .foregroundStyle(FVColor.silver)
                .focused($isFocused)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(FVColor.abyss.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isFocused ? FVColor.cyan.opacity(0.5) : Color.white.opacity(0.06),
                        lineWidth: isFocused ? 1.5 : 1
                    )
                    .animation(.easeOut(duration: 0.2), value: isFocused)
            )
            .shadow(color: isFocused ? FVColor.cyan.opacity(0.1) : .clear, radius: 10, y: 4)
        }
    }
}

// MARK: - Animated Security Gauge

struct FVSecurityGauge: View {
    let score: Int
    var size: CGFloat = 120
    @State private var animatedScore: CGFloat = 0
    @State private var appeared = false

    private var gaugeColor: Color {
        switch score {
        case 0..<40:   return FVColor.danger
        case 40..<70:  return FVColor.warning
        case 70..<85:  return FVColor.warning
        case 85..<95:  return FVColor.cyan
        default:       return FVColor.success
        }
    }

    private var label: String {
        switch score {
        case 0..<40:   return String(localized: "gauge.critical")
        case 40..<70:  return String(localized: "gauge.weak")
        case 70..<85:  return String(localized: "gauge.medium")
        case 85..<95:  return String(localized: "gauge.good")
        default:       return String(localized: "gauge.excellent")
        }
    }

    var body: some View {
        let ringWidth = max(8, size * 0.083)
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: ringWidth)

            // Animated ring
            Circle()
                .trim(from: 0, to: animatedScore / 100)
                .stroke(
                    AngularGradient(
                        colors: [gaugeColor.opacity(0.3), gaugeColor, gaugeColor],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(Double(animatedScore) * 3.6)
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: size < 80 ? 0 : 2) {
                Text("\(Int(animatedScore))")
                    .font(FVFont.display(size * 0.3))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                if size >= 80 {
                    Text(label)
                        .font(FVFont.caption(size * 0.09))
                        .foregroundStyle(gaugeColor)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !appeared else { return }
            appeared = true
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7).delay(0.3)) {
                animatedScore = CGFloat(score)
            }
        }
        .onChange(of: score) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedScore = CGFloat(newValue)
            }
        }
    }
}

// MARK: - Brand Logo

struct FVBrandLogo: View {
    var size: CGFloat = 40
    var animated: Bool = true
    @State private var rotate = false
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(RadialGradient(colors: [FVColor.cyan.opacity(0.3), .clear], center: .center, startRadius: size * 0.3, endRadius: size * 0.8))
                .frame(width: size * 1.6, height: size * 1.6)
                .scaleEffect(glowPulse ? 1.15 : 1.0)

            // Main circle
            Circle()
                .fill(FVGradient.cyanToViolet)
                .frame(width: size, height: size)

            // Shield icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(FVColor.abyss)
                .rotationEffect(.degrees(rotate ? 360 : 0))
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotate = true
            }
        }
    }
}

// MARK: - Brand Header

struct FVBrandHeader: View {
    var subtitle: String = ""
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 8 : 14) {
            FVBrandLogo(size: compact ? 36 : 44)

            VStack(spacing: 4) {
                Text("FYXXVAULT")
                    .font(FVFont.display(compact ? 14 : 16))
                    .kerning(3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FVColor.cyan, FVColor.cyanLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(FVFont.body(compact ? 13 : 15))
                        .foregroundStyle(FVColor.mist.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: - Stat Pill

struct FVStatPill: View {
    let icon: String
    let title: String
    let value: String
    var color: Color = FVColor.cyan

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 3, height: 38)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color.opacity(0.8))
                    Text(title)
                        .font(FVFont.caption(10))
                        .foregroundStyle(FVColor.smoke)
                }
                Text(value)
                    .font(FVFont.heading(26))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.11), Color.white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: color.opacity(0.1), radius: 10, y: 4)
    }
}

// MARK: - Animated Counter

struct FVAnimatedCounter: View {
    let value: Int
    var font: Font = FVFont.heading(22)

    @State private var displayedValue: Int = 0

    var body: some View {
        Text("\(displayedValue)")
            .font(font)
            .contentTransition(.numericText())
            .onAppear {
                withAnimation(.spring(response: 0.8)) { displayedValue = value }
            }
            .onChange(of: value) { _, newVal in
                withAnimation(.spring(response: 0.5)) { displayedValue = newVal }
            }
    }
}

// MARK: - Tag Pill

struct FVTag: View {
    let text: String
    var color: Color = FVColor.cyan

    var body: some View {
        Text(text)
            .font(FVFont.caption(10))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.1))
            .overlay(Capsule().strokeBorder(color.opacity(0.2), lineWidth: 0.8))
            .clipShape(Capsule())
    }
}

// MARK: - Section Header

struct FVSectionHeader: View {
    let icon: String
    let title: String
    var color: Color = FVColor.smoke

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(FVFont.caption(11))
                .kerning(1.5)
                .foregroundStyle(color)
            Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
        }
    }
}

// MARK: - Settings Row Button

struct FVSettingsButton: ButtonStyle {
    var tint: Color = FVColor.cyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FVFont.body(14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .foregroundStyle(tint)
            .background(tint.opacity(configuration.isPressed ? 0.08 : 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tint.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Custom Tab Bar

struct FVTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        ZStack {
            // Background capsule
            Capsule(style: .continuous)
                .fill(FVColor.abyss.opacity(0.92))
                .overlay(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.3))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.14), FVColor.violet.opacity(0.12), Color.white.opacity(0.06)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .frame(height: 68)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 8)

            // Tab items
            HStack(spacing: 0) {
                // Left — Sécurité
                FVTabItem(icon: "shield.checkered", label: "Sécurité", index: 0, selected: $selectedTab)
                    .frame(maxWidth: .infinity)

                // Center spacer for the floating button
                Color.clear.frame(width: 80)

                // Right — Réglages
                FVTabItem(icon: "gearshape.fill", label: "Réglages", index: 2, selected: $selectedTab)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)

            // Center floating button — Coffre
            FVTabCenterItem(icon: "lock.shield.fill", index: 1, selected: $selectedTab)
                .offset(y: -22)
        }
        .frame(maxWidth: 420)
        .frame(height: 68)
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }
}

struct FVTabItem: View {
    let icon: String
    let label: String
    let index: Int
    @Binding var selected: Int

    private var isSelected: Bool { selected == index }

    var body: some View {
        Button {
            fvHaptic(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selected = index
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: isSelected ? .bold : .medium))
                    .symbolRenderingMode(.hierarchical)
                    .frame(height: 22)

                Text(label)
                    .font(FVFont.caption(10))
                    .kerning(0.3)
                    .lineLimit(1)

                Circle()
                    .fill(FVColor.cyan)
                    .frame(width: 5, height: 5)
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.3)
            }
            .foregroundStyle(isSelected ? FVColor.cyan : FVColor.smoke)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct FVTabCenterItem: View {
    let icon: String
    let index: Int
    @Binding var selected: Int
    @State private var glowPulse = false

    private var isSelected: Bool { selected == index }

    var body: some View {
        Button {
            fvHaptic(.medium)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selected = index
            }
        } label: {
            ZStack {
                // Outer glow
                Circle()
                    .fill(FVColor.cyan.opacity(isSelected ? 0.2 : 0.08))
                    .frame(width: 72, height: 72)
                    .scaleEffect(glowPulse ? 1.08 : 1.0)

                // Main circle
                Circle()
                    .fill(FVGradient.cyanToViolet)
                    .frame(width: 58, height: 58)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5)
                    )
                    .shadow(color: FVColor.cyan.opacity(isSelected ? 0.45 : 0.2), radius: 16, y: 4)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

// MARK: - Haptic Feedback

func fvHaptic(_ style: FVHapticStyle = .light) {
    #if canImport(UIKit)
    switch style {
    case .light:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    case .medium:
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    case .heavy:
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    case .success:
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    case .error:
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    #endif
}

enum FVHapticStyle { case light, medium, heavy, success, error }

// MARK: - Animated Appearance Modifier

struct FVAppearAnimation: ViewModifier {
    let delay: Double
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 20)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                    visible = true
                }
            }
    }
}

extension View {
    func fvAppear(delay: Double = 0) -> some View {
        modifier(FVAppearAnimation(delay: delay))
    }
}

// MARK: - Shimmer Effect

struct FVShimmer: ViewModifier {
    @State private var offset: CGFloat = -300

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.05), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: offset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: false)) {
                        offset = 300
                    }
                }
            )
            .clipped()
    }
}

extension View {
    func fvShimmer() -> some View { modifier(FVShimmer()) }
}

// MARK: - Onboarding Feature Card

struct FVOnboardingFeature: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 90, height: 90)
                    .scaleEffect(appeared ? 1 : 0.3)

                Circle()
                    .fill(color.opacity(0.06))
                    .frame(width: 130, height: 130)
                    .scaleEffect(appeared ? 1 : 0)

                Image(systemName: icon)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(color)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .rotationEffect(.degrees(appeared ? 0 : -20))
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: appeared)

            Text(title)
                .font(FVFont.heading(22))
                .foregroundStyle(.white)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)
                .animation(.spring(response: 0.6).delay(0.4), value: appeared)

            Text(description)
                .font(FVFont.body(14))
                .foregroundStyle(FVColor.mist.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(.spring(response: 0.6).delay(0.5), value: appeared)
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}

// MARK: - Password Requirement Row

struct FVRequirementRow: View {
    let label: String
    let met: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(met ? FVColor.success : FVColor.ash)

            Text(label)
                .font(FVFont.caption(12))
                .foregroundStyle(met ? FVColor.success : FVColor.smoke)
        }
        .animation(.easeOut(duration: 0.2), value: met)
    }
}

// MARK: - Empty State

struct FVEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(FVColor.ash)
            Text(title)
                .font(FVFont.heading(18))
                .foregroundStyle(FVColor.silver)
            Text(subtitle)
                .font(FVFont.body(14))
                .foregroundStyle(FVColor.smoke)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .fvGlass()
    }
}

// MARK: - Section Border Modifier

struct FVSectionBorder: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color.opacity(0.6))
                    .frame(width: 2.5)
                    .padding(.vertical, 12)
            }
    }
}

extension View {
    func fvSectionBorder(_ color: Color) -> some View {
        modifier(FVSectionBorder(color: color))
    }
}

// MARK: - Pro Badge

struct FVProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 8, weight: .black, design: .rounded))
            .kerning(1)
            .foregroundStyle(FVColor.abyss)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(FVGradient.goldShimmer)
            .clipShape(Capsule())
            .shadow(color: FVColor.gold.opacity(0.3), radius: 4, y: 1)
    }
}

// MARK: - Premium Card with Animated Gradient Border

struct FVPremiumCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 20
    var borderColors: [Color] = [FVColor.cyan, FVColor.violet, FVColor.rose, FVColor.gold, FVColor.cyan]
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.35))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(FVGradient.cardGlass.opacity(0.9))
                    // Inner glow on edges
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            RadialGradient(
                                colors: [Color.white.opacity(0.08), .clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 200
                            ),
                            lineWidth: 1.5
                        )
                        .blur(radius: 2)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            colors: borderColors,
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: 1.5
                    )
                    .opacity(0.6)
            )
            // 3-layer depth shadows
            .shadow(color: FVColor.cyan.opacity(0.06), radius: 4, y: 2)
            .shadow(color: FVColor.violet.opacity(0.05), radius: 12, y: 6)
            .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
            .onAppear {
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

extension View {
    func fvPremiumCard(cornerRadius: CGFloat = 24, padding: CGFloat = 20) -> some View {
        modifier(FVPremiumCard(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Animated Gradient Text

struct FVAnimatedGradientTextModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    var colors: [Color] = [FVColor.cyan, FVColor.violet, FVColor.gold, FVColor.cyan]
    var speed: Double = 3.0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: colors,
                    startPoint: UnitPoint(x: phase, y: 0),
                    endPoint: UnitPoint(x: phase + 1, y: 1)
                )
                .mask(content)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func fvAnimatedGradient(colors: [Color] = [FVColor.cyan, FVColor.violet, FVColor.gold, FVColor.cyan], speed: Double = 3.0) -> some View {
        modifier(FVAnimatedGradientTextModifier(colors: colors, speed: speed))
    }
}

// MARK: - Pulsing Status Dot

struct FVPulsingDot: View {
    var color: Color = FVColor.success
    var size: CGFloat = 8
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(pulse ? 1.3 : 0.8)
                .opacity(pulse ? 0 : 0.6)

            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Animated Count Badge

struct FVCountBadge: View {
    let count: Int
    var color: Color = FVColor.cyan
    @State private var scale: CGFloat = 1.0
    @State private var previousCount: Int = 0

    var body: some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, count > 99 ? 6 : 5)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, FVColor.violet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .clipShape(Capsule())
            .scaleEffect(scale)
            .onChange(of: count) { _, _ in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                    scale = 1.3
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.15)) {
                    scale = 1.0
                }
            }
    }
}

// MARK: - Skeleton Loading View

struct FVSkeletonView: View {
    var height: CGFloat = 44
    var cornerRadius: CGFloat = 12
    @State private var shimmerOffset: CGFloat = -300

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.08), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerOffset = 300
                }
            }
    }
}

