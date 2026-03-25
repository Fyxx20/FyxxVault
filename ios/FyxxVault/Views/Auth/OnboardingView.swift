import SwiftUI

struct OnboardingView: View {
    @ObservedObject var authManager: AuthManager
    @State private var page = 0

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            FVBrandHeader(subtitle: "Bienvenue dans ton coffre sécurisé")
            TabView(selection: $page) {
                FVOnboardingFeature(
                    icon: "lock.doc.fill", title: "Coffre Chiffré",
                    description: "Tes identifiants sont stockés avec AES-GCM 256-bit et HMAC-SHA256.",
                    color: FVColor.cyan
                ).tag(0)

                FVOnboardingFeature(
                    icon: "checkmark.shield.fill", title: "MFA Par Compte",
                    description: "Ajoute une clé MFA (TOTP) pour chaque service.",
                    color: FVColor.violet
                ).tag(1)

                FVOnboardingFeature(
                    icon: "wand.and.stars", title: "Génération Intelligente",
                    description: "Crée des mots de passe robustes et vérifie leur sécurité.",
                    color: FVColor.gold
                ).tag(2)

                FVOnboardingFeature(
                    icon: "key.fill", title: "Clé de récupération",
                    description: "Tu as reçu une clé unique. Conserve-la précieusement.",
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

            FVButton(title: page < 3 ? "Continuer" : "Entrer dans le coffre") {
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
