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
    @State private var showSaveSuccess = false

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
                VStack(spacing: 24) {
                    // MARK: - Category Picker (horizontal scroll, larger icons)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "vault.add.category"))
                            .font(FVFont.caption(11))
                            .kerning(1.2)
                            .foregroundStyle(FVColor.smoke)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(VaultCategory.allCases) { cat in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            category = cat
                                        }
                                        customFields = cat.suggestedFieldKeys.map { VaultCustomField(key: $0, value: "") }
                                        fvHaptic(.light)
                                    } label: {
                                        VStack(spacing: 6) {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(category == cat
                                                      ? cat.iconColor.opacity(0.15)
                                                      : Color.white.opacity(0.04))
                                                .frame(width: 50, height: 50)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .strokeBorder(
                                                            category == cat ? cat.iconColor.opacity(0.4) : Color.white.opacity(0.06),
                                                            lineWidth: 1
                                                        )
                                                )
                                                .overlay {
                                                    Image(systemName: cat.iconName)
                                                        .font(.system(size: 18, weight: .medium))
                                                        .foregroundStyle(category == cat ? cat.iconColor : FVColor.smoke)
                                                }

                                            Text(cat.label)
                                                .font(FVFont.caption(9))
                                                .foregroundStyle(category == cat ? .white : FVColor.smoke)
                                                .lineLimit(1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: category)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .fvGlass()

                    // MARK: - Category-specific fields
                    categoryFields

                    // Notes (always shown)
                    FVTextField(title: String(localized: "vault.field.notes"), text: $notes)

                    Toggle(String(localized: "vault.add.mark.favorite"), isOn: $isFavorite)
                        .toggleStyle(.switch)
                        .fvGlass()

                    // MARK: - Warnings
                    if category == .login || category == .wifiPassword || category == .softwareLicense,
                       isReusedPassword && !password.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(String(localized: "vault.warning.reused.password"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    if let pwnedCount, pwnedCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundStyle(FVColor.danger)
                            Text(String(format: NSLocalizedString("vault.warning.breached %lld", comment: ""), pwnedCount))
                                .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(FVColor.danger.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    if hasInsecureHTTPURL {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.open.trianglebadge.exclamationmark.fill")
                                .foregroundStyle(FVColor.danger)
                            Text(String(localized: "vault.warning.insecure.url"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(FVColor.danger.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
                    }
                    if isDuplicateEntry {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.doc.fill")
                                .foregroundStyle(.orange)
                            Text(String(localized: "vault.warning.duplicate"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
                    }

                    // MARK: - MFA Section
                    if category == .login {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(String(localized: "vault.add.enable.mfa"), isOn: $mfaEnabled).toggleStyle(.switch)
                            if mfaEnabled {
                                FVTextField(title: String(localized: "vault.field.mfa.secret"), text: $mfaSecret, secure: true)
                                Button(String(localized: "vault.add.scan.qr")) {
                                    showScanner = true
                                    fvHaptic(.light)
                                }
                                .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(FVColor.cyan)
                            }
                        }.fvGlass()
                    }

                    // MARK: - Custom Fields
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "vault.add.custom.fields")).font(FVFont.caption(11)).kerning(1.2).foregroundStyle(FVColor.smoke)
                        FVTextField(title: String(localized: "vault.field.custom.key"), text: $newFieldKey)
                        FVTextField(title: String(localized: "vault.field.custom.value"), text: $newFieldValue)
                        Button(String(localized: "vault.add.custom.field.add")) {
                            let k = newFieldKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            let v = newFieldValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !k.isEmpty, !v.isEmpty else { return }
                            customFields.append(VaultCustomField(key: k, value: v))
                            newFieldKey = ""; newFieldValue = ""
                            fvHaptic(.light)
                        }.foregroundStyle(FVColor.cyan)
                        ForEach(customFields) { f in
                            HStack { Text(f.key).foregroundStyle(.white.opacity(0.9)); Spacer(); Text(f.value).foregroundStyle(.white.opacity(0.65)) }
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                    }.fvGlass()

                    // MARK: - Save Button (full-width gradient)
                    Button {
                        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let effectivePassword = category == .secureNote ? " " : password
                        guard !cleanTitle.isEmpty, !effectivePassword.trimmingCharacters(in: .whitespaces).isEmpty || category == .secureNote, !isDuplicateEntry else { return }
                        guard !mfaEnabled || !mfaSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        fvHaptic(.success)
                        showSaveSuccess = true
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if showSaveSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .font(.system(size: 15, weight: .bold))
                                Text(String(localized: "vault.action.save"))
                                    .font(FVFont.label(15))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(FVGradient.cyanToViolet)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: FVColor.cyan.opacity(0.3), radius: 16, y: 6)
                        .shadow(color: FVColor.violet.opacity(0.15), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showSaveSuccess)
                }
                .padding(.top, 10).padding(.horizontal, 20).padding(.bottom, 30)
            }
            .navigationTitle(String(localized: "vault.add.nav.title"))
            .fvInlineNavTitle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(String(localized: "vault.action.close")) { dismiss() }.foregroundStyle(FVColor.cyan) } }
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

            // Premium Strength indicator with animated bar
            PasswordStrengthView(password: password)

            // Password generator in a premium card
            PasswordGeneratorView(policy: $policy) { password = PasswordToolkit.generate(policy: policy) }

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "vault.field.password.expiration")).font(FVFont.caption(11)).kerning(1.2).foregroundStyle(FVColor.smoke)
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

        case .server:
            FVTextField(title: String(localized: "vault.field.account.name"), text: $title)
            FVTextField(title: String(localized: "vault.field.website"), text: $website)
            FVTextField(title: "IP", text: fieldBinding("IP"))
            FVTextField(title: "Port", text: fieldBinding("Port"))
            FVTextField(title: "SSH Key", text: fieldBinding("SSH Key"))

        case .other:
            FVTextField(title: String(localized: "vault.field.account.name"), text: $title)
            FVTextField(title: String(localized: "vault.field.website"), text: $website)
        }
    }
}
