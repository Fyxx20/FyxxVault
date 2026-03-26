import SwiftUI

struct EditVaultEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vaultStore: VaultStore
    let entry: VaultEntry

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
    @State private var expirationPolicy: PasswordExpirationPolicy = .none
    @State private var policy = PasswordPolicy()
    @State private var category: VaultCategory = .login
    @State private var showShareSheet = false
    @State private var showHistorySheet = false
    @State private var showScanner = false
    @State private var pwnedCount: Int?
    @State private var pwnedLookupFailed = false

    private var isReusedPassword: Bool { vaultStore.isPasswordReused(password) }
    private var hasInsecureHTTPURL: Bool { website.lowercased().hasPrefix("http://") }
    private var isDuplicateEntry: Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return vaultStore.entries.contains { $0.id != entry.id && $0.title.lowercased() == t && $0.username.lowercased() == u && !t.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Category picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "vault.add.category")).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(VaultCategory.allCases) { cat in
                                    Button {
                                        category = cat
                                        // Reset custom fields to match new category
                                        customFields = cat.suggestedFieldKeys.map { VaultCustomField(key: $0, value: "") }
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

                    // Category-specific fields
                    categoryFields

                    // Notes (always shown)
                    FVTextField(title: String(localized: "vault.field.notes"), text: $notes)

                    Toggle(String(localized: "vault.edit.favorite"), isOn: $isFavorite).toggleStyle(.switch).fvGlass()

                    // Warnings (only for categories with passwords)
                    if category == .login || category == .wifiPassword || category == .softwareLicense,
                       isReusedPassword && !password.isEmpty {
                        Text(String(localized: "vault.warning.reused.password"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
                    }
                    if let pwnedCount, pwnedCount > 0 {
                        Text(String(format: NSLocalizedString("vault.warning.breached %lld", comment: ""), pwnedCount))
                            .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(FVColor.danger.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
                    }
                    if hasInsecureHTTPURL {
                        Text(String(localized: "vault.warning.insecure.url"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(FVColor.danger.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
                    }
                    if isDuplicateEntry {
                        Text(String(localized: "vault.warning.duplicate"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
                    }

                    // MFA (only for login accounts)
                    if category == .login {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(String(localized: "vault.edit.enable.mfa"), isOn: $mfaEnabled).toggleStyle(.switch)
                            if mfaEnabled {
                                FVTextField(title: String(localized: "vault.field.mfa.secret"), text: $mfaSecret, secure: true)
                                Button(String(localized: "vault.add.scan.qr")) { showScanner = true }
                                    .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(FVColor.cyan)
                            }
                        }.fvGlass()
                    }

                    // Custom fields
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "vault.add.custom.fields")).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        FVTextField(title: String(localized: "vault.field.custom.key"), text: $newFieldKey)
                        FVTextField(title: String(localized: "vault.field.custom.value"), text: $newFieldValue)
                        Button(String(localized: "vault.add.custom.field.add")) {
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

                    // Share & History
                    HStack(spacing: 12) {
                        Button {
                            showShareSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.shield")
                                Text(String(localized: "vault.action.share"))
                            }
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(FVColor.cyan)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(FVColor.cyan.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FVColor.cyan.opacity(0.15)))
                        }

                        Button {
                            showHistorySheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text(String(localized: "vault.action.history"))
                            }
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(FVColor.violet)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(FVColor.violet.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FVColor.violet.opacity(0.15)))
                        }
                    }.fvGlass()

                    FVButton(title: String(localized: "vault.action.save.changes")) {
                        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let effectivePassword = category == .secureNote ? " " : password
                        guard !cleanTitle.isEmpty, !effectivePassword.trimmingCharacters(in: .whitespaces).isEmpty || category == .secureNote, !isDuplicateEntry else { return }
                        guard !mfaEnabled || !mfaSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        let updated = VaultEntry(
                            id: entry.id,
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
                            attachments: entry.attachments,
                            passwordHistory: entry.passwordHistory,
                            createdAt: entry.createdAt,
                            expirationPolicy: expirationPolicy,
                            passwordLastChangedAt: password == entry.password ? entry.passwordLastChangedAt : Date(),
                            category: category
                        )
                        vaultStore.updateEntry(updated)
                        dismiss()
                    }
                }
                .padding(.top, 10).padding(.horizontal, 20).padding(.bottom, 30)
            }
            .navigationTitle(String(localized: "vault.edit.nav.title"))
            .fvInlineNavTitle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(String(localized: "vault.action.close")) { dismiss() }.foregroundStyle(FVColor.cyan) } }
            .fullScreenCover(isPresented: $showScanner) { QRScannerSheet { scanned in mfaSecret = scanned; showScanner = false } }
            .background(FVAnimatedBackground())
            .sheet(isPresented: $showShareSheet) { ShareEntryView(entry: entry) }
            .sheet(isPresented: $showHistorySheet) { PasswordHistoryView(history: entry.passwordHistory, currentPassword: entry.password) }
            .onAppear {
                title = entry.title; username = entry.username; password = entry.password
                website = entry.website; notes = entry.notes; mfaEnabled = entry.mfaEnabled
                mfaSecret = entry.mfaSecret; isFavorite = entry.isFavorite
                expirationPolicy = entry.expirationPolicy
                category = entry.category
                customFields = entry.customFields
            }
        }
        .task(id: password) {
            guard password.count >= 8 else { pwnedCount = nil; pwnedLookupFailed = false; return }
            let result = await PasswordBreachService.compromisedCount(password: password)
            pwnedCount = result
            pwnedLookupFailed = (result == nil)
        }
    }

    // MARK: - Category-Specific Fields

    private func fieldBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { customFields.first(where: { $0.key == key })?.value ?? "" },
            set: { val in
                if let idx = customFields.firstIndex(where: { $0.key == key }) {
                    customFields[idx].value = val
                }
            }
        )
    }

    @ViewBuilder
    private var categoryFields: some View {
        switch category {
        case .login:
            FVTextField(title: String(localized: "vault.field.account.name"), text: $title)
            FVTextField(title: String(localized: "vault.field.website"), text: $website)
            FVTextField(title: String(localized: "vault.field.username"), text: $username)
            FVTextField(title: String(localized: "vault.field.password"), text: $password)
            PasswordStrengthView(password: password)
            PasswordGeneratorView(policy: $policy) { password = PasswordToolkit.generate(policy: policy) }
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "vault.field.password.expiration")).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Picker(String(localized: "vault.field.expiration"), selection: $expirationPolicy) {
                    ForEach(PasswordExpirationPolicy.allCases) { p in Text(p.label).tag(p) }
                }.pickerStyle(.menu).foregroundStyle(FVColor.cyan)
            }.fvGlass()

        case .creditCard:
            FVTextField(title: String(localized: "vault.field.card.name"), text: $title)
            FVTextField(title: String(localized: "vault.field.cardholder"), text: $username)
            FVTextField(title: String(localized: "vault.field.card.number"), text: fieldBinding("Numéro de carte"))
                .keyboardType(.numberPad)
            HStack(spacing: 12) {
                FVTextField(title: String(localized: "vault.field.card.expiry"), text: fieldBinding("Date d'expiration"))
                    .keyboardType(.numberPad)
                FVTextField(title: "CVV", text: fieldBinding("CVV"), secure: true)
                    .keyboardType(.numberPad)
            }

        case .identity:
            FVTextField(title: String(localized: "vault.field.full.name"), text: $title)
            FVTextField(title: String(localized: "vault.field.first.name"), text: fieldBinding("Prénom"))
            FVTextField(title: String(localized: "vault.field.last.name"), text: fieldBinding("Nom"))
            FVTextField(title: String(localized: "vault.field.date.of.birth"), text: fieldBinding("Date de naissance"))
            FVTextField(title: String(localized: "vault.field.address"), text: fieldBinding("Adresse"))
            FVTextField(title: String(localized: "vault.field.phone"), text: fieldBinding("Téléphone"))
                .keyboardType(.phonePad)
            FVTextField(title: String(localized: "vault.field.email"), text: $username)
                .keyboardType(.emailAddress)

        case .secureNote:
            FVTextField(title: String(localized: "vault.field.note.title"), text: $title)

        case .wifiPassword:
            FVTextField(title: String(localized: "vault.field.network.name"), text: $title)
            FVTextField(title: "SSID", text: fieldBinding("SSID"))
            FVTextField(title: String(localized: "vault.field.wifi.password"), text: $password, secure: true)
            PasswordStrengthView(password: password)
            FVTextField(title: String(localized: "vault.field.security.type"), text: fieldBinding("Type de sécurité"))

        case .softwareLicense:
            FVTextField(title: String(localized: "vault.field.software.name"), text: $title)
            FVTextField(title: String(localized: "vault.field.website"), text: $website)
            FVTextField(title: String(localized: "vault.field.license.key"), text: $password)
            FVTextField(title: String(localized: "vault.field.account.email"), text: $username)
            FVTextField(title: String(localized: "vault.field.version"), text: fieldBinding("Version"))
            FVTextField(title: String(localized: "vault.field.purchase.date"), text: fieldBinding("Date d'achat"))

        case .passport:
            FVTextField(title: String(localized: "vault.field.full.name"), text: $title)
            FVTextField(title: String(localized: "vault.field.passport.number"), text: fieldBinding("Numéro"))
            FVTextField(title: String(localized: "vault.field.issuing.country"), text: fieldBinding("Pays"))
            FVTextField(title: String(localized: "vault.field.expiration.date"), text: fieldBinding("Date d'expiration"))
            FVTextField(title: String(localized: "vault.field.date.of.birth"), text: fieldBinding("Date de naissance"))

        case .bankAccount:
            FVTextField(title: String(localized: "vault.field.account.name"), text: $title)
            FVTextField(title: String(localized: "vault.field.bank"), text: fieldBinding("Banque"))
            FVTextField(title: "IBAN", text: fieldBinding("IBAN"))
            FVTextField(title: String(localized: "vault.field.bic.swift"), text: fieldBinding("BIC"))
            FVTextField(title: String(localized: "vault.field.account.number"), text: fieldBinding("Numéro de compte"))
            FVTextField(title: String(localized: "vault.field.cardholder"), text: $username)
        }
    }
}
