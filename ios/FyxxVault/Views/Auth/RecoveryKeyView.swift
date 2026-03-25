import SwiftUI

struct RecoveryKeyView: View {
    let recoveryKey: String
    let onDismiss: () -> Void
    @State private var confirmed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    FVBrandLogo(size: 50)

                    Text("Clé de récupération")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Si vous oubliez votre mot de passe maître, cette clé est le SEUL moyen de récupérer votre compte. Elle ne sera plus affichée.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 8) {
                        Text(recoveryKey)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(FVColor.cyanLight)
                            .multilineTextAlignment(.center)
                            .padding(16)
                            .background(FVColor.abyss.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FVColor.cyan.opacity(0.5), lineWidth: 1))
                            .fvGlow(FVColor.cyan)

                        FVButton(title: "Copier la clé", icon: "doc.on.doc", style: .secondary) {
                            ClipboardService.copy(recoveryKey.replacingOccurrences(of: "-", with: ""))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notez-la sur papier dans un endroit sûr", systemImage: "pencil.and.list.clipboard")
                        Label("Ne la partagez jamais", systemImage: "person.slash")
                        Label("Ne la stockez pas dans un fichier non chiffré", systemImage: "doc.badge.ellipsis")
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fvGlass()

                    Toggle("J'ai sauvegardé ma clé de récupération", isOn: $confirmed)
                        .toggleStyle(.switch)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    FVButton(title: "Continuer") {
                        guard confirmed else { return }
                        onDismiss()
                    }
                    .opacity(confirmed ? 1 : 0.4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle("Clé de récupération")
            .fvInlineNavTitle()
            .background(FVAnimatedBackground())
        }
        .interactiveDismissDisabled(!confirmed)
    }
}
