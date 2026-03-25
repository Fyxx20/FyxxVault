import SwiftUI

struct PasswordStrengthView: View {
    let password: String
    var strength: PasswordStrength { PasswordToolkit.strength(for: password) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "strength.title")).font(FVFont.body(13)).foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 10) {
                Capsule().fill(strength.color).frame(width: 66, height: 10)
                Text(strength.label).font(FVFont.body(14)).foregroundStyle(strength.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }
}
