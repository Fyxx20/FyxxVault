import SwiftUI

struct PasswordGeneratorView: View {
    @Binding var policy: PasswordPolicy
    var onGenerate: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "generator.title")).font(FVFont.body(16)).foregroundStyle(.white)
            Picker(String(localized: "generator.mode"), selection: $policy.mode) {
                ForEach(PasswordGenerationMode.allCases) { m in Text(m.rawValue).tag(m) }
            }.pickerStyle(.segmented)
            if policy.mode == .random {
                Text(String(localized: "generator.length \(policy.length)")).font(FVFont.body(13)).foregroundStyle(.white.opacity(0.8))
                Slider(value: Binding(get: { Double(policy.length) }, set: { policy.length = Int($0) }), in: 8...40, step: 1).tint(FVColor.cyan)
                Toggle(String(localized: "generator.uppercase"), isOn: $policy.includeUppercase)
                Toggle(String(localized: "generator.lowercase"), isOn: $policy.includeLowercase)
                Toggle(String(localized: "generator.numbers"), isOn: $policy.includeNumbers)
                Toggle(String(localized: "generator.symbols"), isOn: $policy.includeSymbols)
            } else {
                Stepper(String(localized: "generator.word.count \(policy.wordsCount)"), value: $policy.wordsCount, in: 3...8).foregroundStyle(.white.opacity(0.85))
            }
            FVButton(title: String(localized: "generator.generate")) { onGenerate() }
        }
        .toggleStyle(.switch).fvGlass()
    }
}
