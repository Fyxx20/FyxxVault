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

                    Text(String(localized: "recovery.title"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(String(localized: "recovery.warning"))
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

                        FVButton(title: String(localized: "recovery.button.copy"), icon: "doc.on.doc", style: .secondary) {
                            ClipboardService.copy(recoveryKey.replacingOccurrences(of: "-", with: ""))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label(String(localized: "recovery.tip.write_down"), systemImage: "pencil.and.list.clipboard")
                        Label(String(localized: "recovery.tip.never_share"), systemImage: "person.slash")
                        Label(String(localized: "recovery.tip.no_unencrypted"), systemImage: "doc.badge.ellipsis")
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fvGlass()

                    Toggle(String(localized: "recovery.toggle.saved"), isOn: $confirmed)
                        .toggleStyle(.switch)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    FVButton(title: String(localized: "recovery.button.continue")) {
                        guard confirmed else { return }
                        onDismiss()
                    }
                    .opacity(confirmed ? 1 : 0.4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle(String(localized: "recovery.nav.title"))
            .fvInlineNavTitle()
            .background(FVAnimatedBackground())
        }
        .interactiveDismissDisabled(!confirmed)
    }
}
