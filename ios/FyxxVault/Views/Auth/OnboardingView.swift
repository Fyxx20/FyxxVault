import SwiftUI

struct OnboardingView: View {
    @ObservedObject var authManager: AuthManager
    @State private var page = 0
    @State private var appeared = false

    private let features: [(icon: String, title: String, description: String, color: Color, badge: String)] = [
        (
            icon: "shield.lefthalf.filled",
            title: String(localized: "onboarding.aes.title"),
            description: String(localized: "onboarding.aes.description"),
            color: FVColor.cyan,
            badge: String(localized: "onboarding.aes.badge")
        ),
        (
            icon: "key.horizontal.fill",
            title: String(localized: "onboarding.mfa.title"),
            description: String(localized: "onboarding.mfa.description"),
            color: FVColor.violet,
            badge: String(localized: "onboarding.mfa.badge")
        ),
        (
            icon: "cloud.fill",
            title: String(localized: "onboarding.sync.title"),
            description: String(localized: "onboarding.sync.description"),
            color: FVColor.success,
            badge: String(localized: "onboarding.sync.badge")
        ),
        (
            icon: "eye.slash.fill",
            title: String(localized: "onboarding.panic.title"),
            description: String(localized: "onboarding.panic.description"),
            color: FVColor.danger,
            badge: String(localized: "onboarding.panic.badge")
        )
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                Spacer(minLength: 20)

                // Brand header - compact
                FVBrandHeader(subtitle: "", compact: true)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -20)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1), value: appeared)

                Spacer(minLength: 16)

                // Feature pages
                TabView(selection: $page) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        OnboardingFeaturePage(
                            icon: feature.icon,
                            title: feature.title,
                            description: feature.description,
                            color: feature.color,
                            badge: feature.badge
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 380)

                Spacer(minLength: 20)

                // Progress dots
                HStack(spacing: 10) {
                    ForEach(0..<features.count, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? features[page].color : Color.white.opacity(0.18))
                            .frame(width: i == page ? 28 : 8, height: 8)
                            .shadow(color: i == page ? features[page].color.opacity(0.5) : .clear, radius: 6, y: 0)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: page)
                    }
                }
                .padding(.bottom, 24)

                // CTA button
                if page < features.count - 1 {
                    FVButton(title: String(localized: "onboarding.continue"), icon: "arrow.right") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            page += 1
                        }
                    }
                    .padding(.horizontal, 32)
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                } else {
                    FVButton(title: String(localized: "onboarding.start"), icon: "lock.shield.fill", style: .gold) {
                        fvHaptic(.success)
                        authManager.completeOnboarding()
                    }
                    .padding(.horizontal, 32)
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                }

                Spacer(minLength: 30)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: page)

            // Skip button top right
            if page < features.count - 1 {
                Button {
                    fvHaptic(.light)
                    authManager.completeOnboarding()
                } label: {
                    Text(String(localized: "onboarding.skip"))
                        .font(FVFont.body(13))
                        .foregroundStyle(FVColor.smoke)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                }
                .padding(.top, 16)
                .padding(.trailing, 24)
                .transition(.opacity)
            }
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Feature Page (premium)

private struct OnboardingFeaturePage: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let badge: String

    @State private var iconAppeared = false
    @State private var contentAppeared = false
    @State private var pulseGlow = false

    var body: some View {
        VStack(spacing: 24) {
            // Icon area with layered circles
            ZStack {
                // Outer pulse ring
                Circle()
                    .fill(color.opacity(0.04))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseGlow ? 1.12 : 0.95)

                // Mid ring
                Circle()
                    .fill(color.opacity(0.08))
                    .frame(width: 120, height: 120)
                    .scaleEffect(iconAppeared ? 1 : 0.3)

                // Inner ring
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 90, height: 90)
                    .scaleEffect(iconAppeared ? 1 : 0.5)

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(iconAppeared ? 1 : 0.4)
                    .rotationEffect(.degrees(iconAppeared ? 0 : -15))
                    .symbolRenderingMode(.hierarchical)
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.15), value: iconAppeared)

            // Badge
            Text(badge)
                .font(FVFont.caption(10))
                .kerning(1.8)
                .foregroundStyle(color)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 1))
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 10)
                .animation(.spring(response: 0.6).delay(0.3), value: contentAppeared)

            // Title
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 12)
                .animation(.spring(response: 0.6).delay(0.4), value: contentAppeared)

            // Description
            Text(description)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.mist.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 8)
                .animation(.spring(response: 0.6).delay(0.5), value: contentAppeared)
        }
        .onAppear {
            iconAppeared = true
            contentAppeared = true
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
        .onDisappear {
            iconAppeared = false
            contentAppeared = false
            pulseGlow = false
        }
    }
}
