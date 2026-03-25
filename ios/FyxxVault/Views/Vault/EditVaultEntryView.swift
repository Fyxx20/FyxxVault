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
    @State private var expirationPolicy: PasswordExpirationPolicy = .none
    @State private var category: VaultCategory = .login

    private var isDuplicateEntry: Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return vaultStore.entries.contains { $0.id != entry.id && $0.title.lowercased() == t && $0.username.lowercased() == u && !t.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Category picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(VaultCategory.allCases) { cat in
                                Button {
                                    category = cat
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
                    .fvGlass()

                    FVTextField(title: String(localized: "vault.field.account.name"), text: $title)
                    FVTextField(title: String(localized: "vault.field.website"), text: $website)
                    FVTextField(title: String(localized: "vault.field.username"), text: $username)
                    FVTextField(title: String(localized: "vault.field.password"), text: $password)
                    PasswordStrengthView(password: password)
                    FVTextField(title: String(localized: "vault.field.notes"), text: $notes)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "vault.field.password.expiration")).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        Picker(String(localized: "vault.field.expiration"), selection: $expirationPolicy) {
                            ForEach(PasswordExpirationPolicy.allCases) { p in Text(p.label).tag(p) }
                        }.pickerStyle(.menu).foregroundStyle(FVColor.cyan)
                    }.fvGlass()

                    Toggle(String(localized: "vault.edit.favorite"), isOn: $isFavorite).toggleStyle(.switch).fvGlass()
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(String(localized: "vault.edit.enable.mfa"), isOn: $mfaEnabled).toggleStyle(.switch)
                        if mfaEnabled { FVTextField(title: String(localized: "vault.field.mfa.secret.short"), text: $mfaSecret, secure: true) }
                    }.fvGlass()

                    if isDuplicateEntry {
                        Text(String(localized: "vault.warning.duplicate.short")).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading).fvGlass()
                    }

                    FVButton(title: String(localized: "vault.action.save.changes")) {
                        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty, !isDuplicateEntry else { return }
                        let updated = VaultEntry(
                            id: entry.id,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password,
                            website: website.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            mfaEnabled: mfaEnabled,
                            mfaType: mfaEnabled ? .totp : nil,
                            mfaSecret: mfaEnabled ? mfaSecret : "",
                            isFavorite: isFavorite,
                            customFields: entry.customFields,
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
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 26)
            }
            .navigationTitle(String(localized: "vault.edit.nav.title"))
            .fvInlineNavTitle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(String(localized: "vault.action.close")) { dismiss() }.foregroundStyle(FVColor.cyan) } }
            .background(FVAnimatedBackground())
            .onAppear {
                title = entry.title; username = entry.username; password = entry.password
                website = entry.website; notes = entry.notes; mfaEnabled = entry.mfaEnabled
                mfaSecret = entry.mfaSecret; isFavorite = entry.isFavorite
                expirationPolicy = entry.expirationPolicy
                category = entry.category
            }
        }
    }
}
