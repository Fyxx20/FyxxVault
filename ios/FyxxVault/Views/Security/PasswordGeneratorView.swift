import SwiftUI

struct PasswordGeneratorView: View {
    @Binding var policy: PasswordPolicy
    var onGenerate: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Générateur").font(FVFont.body(16)).foregroundStyle(.white)
            Picker("Mode", selection: $policy.mode) {
                ForEach(PasswordGenerationMode.allCases) { m in Text(m.rawValue).tag(m) }
            }.pickerStyle(.segmented)
            if policy.mode == .random {
                Text("Longueur: \(policy.length)").font(FVFont.body(13)).foregroundStyle(.white.opacity(0.8))
                Slider(value: Binding(get: { Double(policy.length) }, set: { policy.length = Int($0) }), in: 8...40, step: 1).tint(FVColor.cyan)
                Toggle("Majuscules", isOn: $policy.includeUppercase)
                Toggle("Minuscules", isOn: $policy.includeLowercase)
                Toggle("Chiffres", isOn: $policy.includeNumbers)
                Toggle("Caractères spéciaux", isOn: $policy.includeSymbols)
            } else {
                Stepper("Nombre de mots: \(policy.wordsCount)", value: $policy.wordsCount, in: 3...8).foregroundStyle(.white.opacity(0.85))
            }
            FVButton(title: "Générer") { onGenerate() }
        }
        .toggleStyle(.switch).fvGlass()
    }
}
