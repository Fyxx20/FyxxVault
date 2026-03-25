import SwiftUI

struct OnboardingView: View {
    @ObservedObject var authManager: AuthManager
    @State private var page = 0

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            FVBrandHeader(subtitle: String(localized: "onboarding.header.subtitle"))
            TabView(selection: $page) {
                FVOnboardingFeature(
                    icon: "lock.doc.fill", title: String(localized: "onboarding.feature.vault.title"),
                    description: String(localized: "onboarding.feature.vault.description"),
                    color: FVColor.cyan
                ).tag(0)

                FVOnboardingFeature(
                    icon: "checkmark.shield.fill", title: String(localized: "onboarding.feature.mfa.title"),
                    description: String(localized: "onboarding.feature.mfa.description"),
                    color: FVColor.violet
                ).tag(1)

                FVOnboardingFeature(
                    icon: "wand.and.stars", title: String(localized: "onboarding.feature.generator.title"),
                    description: String(localized: "onboarding.feature.generator.description"),
                    color: FVColor.gold
                ).tag(2)

                FVOnboardingFeature(
                    icon: "key.fill", title: String(localized: "onboarding.feature.recovery.title"),
                    description: String(localized: "onboarding.feature.recovery.description"),
                    color: FVColor.success
                ).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 290)
            .fvGlass()

            HStack(spacing: 8) {
                ForEach(0..<4) { i in
                    Capsule()
                        .fill(i == page ? FVColor.cyan : Color.white.opacity(0.2))
                        .frame(width: i == page ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: page)
                }
            }

            FVButton(title: page < 3 ? String(localized: "onboarding.button.continue") : String(localized: "onboarding.button.enter")) {
                if page < 3 {
                    withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                } else {
                    authManager.completeOnboarding()
                }
            }
            Spacer(minLength: 0)
        }
    }
}
