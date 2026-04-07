import SwiftUI

struct PasswordGeneratorView: View {
    @Binding var policy: PasswordPolicy
    var onGenerate: () -> Void
    @State private var generateBounce = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [FVColor.cyan.opacity(0.2), FVColor.violet.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FVColor.cyan)
                }
                Text(String(localized: "generator.title"))
                    .font(FVFont.title(15))
                    .foregroundStyle(.white)
            }

            Picker(String(localized: "generator.mode"), selection: $policy.mode) {
                ForEach(PasswordGenerationMode.allCases) { m in Text(m.rawValue).tag(m) }
            }.pickerStyle(.segmented)

            if policy.mode == .random {
                Text(String(format: NSLocalizedString("generator.length %lld", comment: ""), policy.length))
                    .font(FVFont.body(13))
                    .foregroundStyle(.white.opacity(0.8))
                Slider(value: Binding(get: { Double(policy.length) }, set: { policy.length = Int($0) }), in: 8...40, step: 1)
                    .tint(FVColor.cyan)
                Toggle(String(localized: "generator.uppercase"), isOn: $policy.includeUppercase)
                Toggle(String(localized: "generator.lowercase"), isOn: $policy.includeLowercase)
                Toggle(String(localized: "generator.numbers"), isOn: $policy.includeNumbers)
                Toggle(String(localized: "generator.symbols"), isOn: $policy.includeSymbols)
            } else {
                Stepper(String(format: NSLocalizedString("generator.word.count %lld", comment: ""), policy.wordsCount), value: $policy.wordsCount, in: 3...8)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Button {
                fvHaptic(.medium)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                    generateBounce = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    generateBounce = false
                }
                onGenerate()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .rotationEffect(.degrees(generateBounce ? 180 : 0))
                    Text(String(localized: "generator.generate"))
                        .font(FVFont.label(14))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FVGradient.cyanToViolet)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: FVColor.cyan.opacity(0.2), radius: 10, y: 4)
                .scaleEffect(generateBounce ? 0.96 : 1.0)
            }
            .buttonStyle(.plain)
        }
        .toggleStyle(.switch)
        .fvPremiumCard()
    }
}
