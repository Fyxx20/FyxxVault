import SwiftUI

struct LogoutConfirmSheet: View {
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        ZStack {
            FVAnimatedBackground()
            VStack(spacing: 16) {
                Circle()
                    .fill(FVGradient.violetToRose)
                    .frame(width: 62, height: 62)
                    .overlay(
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    )

                Text("Confirmer la déconnexion")
                    .font(FVFont.heading(24))
                    .foregroundStyle(.white)

                Text("Tu devras te reconnecter avec ton email et ton mot de passe maître.")
                    .font(FVFont.body(14))
                    .foregroundStyle(FVColor.mist)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                HStack(spacing: 10) {
                    Button("Annuler", action: onCancel)
                        .buttonStyle(FVSettingsButton(tint: FVColor.silver.opacity(0.45)))
                    Button("Se déconnecter", action: onConfirm)
                        .buttonStyle(FVSettingsButton(tint: FVColor.danger.opacity(0.92)))
                }
            }
            .padding(20)
        }
    }
}
