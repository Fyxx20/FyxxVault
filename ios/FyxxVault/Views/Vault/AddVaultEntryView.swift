import SwiftUI

struct AddVaultEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vaultStore: VaultStore

    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var website = ""
    @State private var notes = ""
    @State private var mfaEnabled = false
    @State private var mfaSecret = ""
    @State private var isFavorite = false
    @State private var customFields: [VaultCustomField] = []
    @State private var newFieldKey = ""
    @State private var newFieldValue = ""
    @State private var showScanner = false
    @State private var pwnedCount: Int?
    @State private var pwnedLookupFailed = false
    @State private var expirationPolicy: PasswordExpirationPolicy = .none
    @State private var policy = PasswordPolicy()
    @State private var category: VaultCategory = .login

    private var isReusedPassword: Bool { vaultStore.isPasswordReused(password) }
    private var hasInsecureHTTPURL: Bool { website.lowercased().hasPrefix("http://") }
    private var isDuplicateEntry: Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return vaultStore.entries.contains { $0.title.lowercased() == t && $0.username.lowercased() == u && !t.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Category picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Catégorie").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(VaultCategory.allCases) { cat in
                                    Button {
                                        category = cat
                                        if cat != .login && customFields.isEmpty {
                                            customFields = cat.suggestedFieldKeys.map { VaultCustomField(key: $0, value: "") }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: cat.iconName).font(.system(size: 11))
                                            Text(cat.label).font(.system(size: 12, weight: .medium, design: .rounded))
                                        }
                                        .foregroundStyle(category == cat ? .white : FVColor.mist)
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(category == cat ? cat.iconColor.opacity(0.3) : Color.white.opacity(0.05))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().strokeBorder(category == cat ? cat.iconColor.opacity(0.5) : Color.white.opacity(0.1)))
                                    }
                                }
                            }
                        }
                    }.fvGlass()

                    FVTextField(title: "Nom du compte", text: $title)
                    FVTextField(title: "Site web", text: $website)
                    FVTextField(title: "Identifiant / Email", text: $username)

                    if category == .creditCard {
                        FVTextField(title: "Numéro de carte", text: Binding(
                            get: { customFields.first(where: { $0.key == "Numéro de carte" })?.value ?? "" },
                            set: { val in if let idx = customFields.firstIndex(where: { $0.key == "Numéro de carte" }) { customFields[idx].value = val } }
                        ))
                        HStack(spacing: 12) {
                            FVTextField(title: "Expiration", text: Binding(
                                get: { customFields.first(where: { $0.key == "Date d'expiration" })?.value ?? "" },
                                set: { val in if let idx = customFields.firstIndex(where: { $0.key == "Date d'expiration" }) { customFields[idx].value = val } }
                            ))
                            FVTextField(title: "CVV", text: Binding(
                                get: { customFields.first(where: { $0.key == "CVV" })?.value ?? "" },
                                set: { val in if let idx = customFields.firstIndex(where: { $0.key == "CVV" }) { customFields[idx].value = val } }
                            ), secure: true)
                        }
                    }

                    if category != .secureNote {
                        FVTextField(title: "Mot de passe", text: $password)
                        PasswordStrengthView(password: password)
                        PasswordGeneratorView(policy: $policy) { password = PasswordToolkit.generate(policy: policy) }
                    }
                    FVTextField(title: "Notes", text: $notes)

                    // Expiration policy
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expiration du mot de passe").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        Picker("Expiration", selection: $expirationPolicy) {
                            ForEach(PasswordExpirationPolicy.allCases) { p in Text(p.label).tag(p) }
                        }.pickerStyle(.menu).foregroundStyle(FVColor.cyan)
                    }.fvGlass()

                    Toggle("Marquer en favori", isOn: $isFavorite).toggleStyle(.switch).fvGlass()

                    // Warnings
                    if isReusedPassword && !password.isEmpty {
                        Text("Attention: ce mot de passe est déjà utilisé sur un autre compte.")
                            .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
                    }
                    if let pwnedCount, pwnedCount > 0 {
                        Text("Compromis: ce mot de passe est apparu dans \(pwnedCount) fuite(s).")
                            .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(FVColor.danger.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
                    }
                    if hasInsecureHTTPURL {
                        Text("URL non sécurisée (http://). Utilise https://.")
                            .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(FVColor.danger.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
                    }
                    if isDuplicateEntry {
                        Text("Doublon détecté: une entrée similaire existe déjà.")
                            .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
                    }

                    // MFA
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Activer MFA TOTP", isOn: $mfaEnabled).toggleStyle(.switch)
                        if mfaEnabled {
                            FVTextField(title: "Clé secrète ou URL otpauth://", text: $mfaSecret, secure: true)
                            Button("Scanner un QR code") { showScanner = true }
                                .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(FVColor.cyan)
                        }
                    }.fvGlass()

                    // Custom fields
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Champs personnalisés").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        FVTextField(title: "Clé (IBAN, PIN, ...)", text: $newFieldKey)
                        FVTextField(title: "Valeur", text: $newFieldValue)
                        Button("Ajouter le champ") {
                            let k = newFieldKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            let v = newFieldValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !k.isEmpty, !v.isEmpty else { return }
                            customFields.append(VaultCustomField(key: k, value: v))
                            newFieldKey = ""; newFieldValue = ""
                        }.foregroundStyle(FVColor.cyan)
                        ForEach(customFields) { f in
                            HStack { Text(f.key).foregroundStyle(.white.opacity(0.9)); Spacer(); Text(f.value).foregroundStyle(.white.opacity(0.65)) }
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                    }.fvGlass()

                    FVButton(title: "Sauvegarder") {
                        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let effectivePassword = category == .secureNote ? " " : password
                        guard !cleanTitle.isEmpty, !effectivePassword.trimmingCharacters(in: .whitespaces).isEmpty || category == .secureNote, !isDuplicateEntry else { return }
                        guard !mfaEnabled || !mfaSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        vaultStore.addEntry(VaultEntry(
                            title: cleanTitle,
                            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: category == .secureNote ? "" : password,
                            website: website.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            mfaEnabled: mfaEnabled,
                            mfaType: mfaEnabled ? .totp : nil,
                            mfaSecret: mfaEnabled ? mfaSecret.trimmingCharacters(in: .whitespacesAndNewlines) : "",
                            isFavorite: isFavorite,
                            customFields: customFields,
                            expirationPolicy: expirationPolicy,
                            category: category
                        ))
                        dismiss()
                    }
                }
                .padding(.top, 10).padding(.horizontal, 20).padding(.bottom, 30)
            }
            .navigationTitle("Nouveau Compte")
            .fvInlineNavTitle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() }.foregroundStyle(FVColor.cyan) } }
            .fullScreenCover(isPresented: $showScanner) { QRScannerSheet { scanned in mfaSecret = scanned; showScanner = false } }
            .background(FVAnimatedBackground())
        }
        .task(id: password) {
            guard password.count >= 8 else { pwnedCount = nil; pwnedLookupFailed = false; return }
            let result = await PasswordBreachService.compromisedCount(password: password)
            pwnedCount = result
            pwnedLookupFailed = (result == nil)
        }
    }
}
