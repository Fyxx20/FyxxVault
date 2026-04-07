import SwiftUI

struct PasswordStrengthView: View {
    let password: String
    var strength: PasswordStrength { PasswordToolkit.strength(for: password) }
    @State private var animatedWidth: CGFloat = 0

    private var targetWidth: CGFloat {
        switch strength {
        case .faible:    return 0.25
        case .moyen:     return 0.5
        case .fort:      return 0.75
        case .excellent: return 1.0
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "strength.title"))
                .font(FVFont.caption(11))
                .kerning(1.0)
                .foregroundStyle(FVColor.smoke)
            HStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 8)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [strength.color.opacity(0.7), strength.color],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * animatedWidth, height: 8)
                            .shadow(color: strength.color.opacity(0.3), radius: 4, y: 1)
                    }
                }
                .frame(height: 8)

                Text(strength.label)
                    .font(FVFont.label(12))
                    .foregroundStyle(strength.color)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fvGlass()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedWidth = targetWidth
            }
        }
        .onChange(of: password) { _, _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                animatedWidth = targetWidth
            }
        }
    }
}
