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

    private var isDuplicateEntry: Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return vaultStore.entries.contains { $0.id != entry.id && $0.title.lowercased() == t && $0.username.lowercased() == u && !t.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    FVTextField(title: "Nom du compte", text: $title)
                    FVTextField(title: "Site web", text: $website)
                    FVTextField(title: "Identifiant / Email", text: $username)
                    FVTextField(title: "Mot de passe", text: $password)
                    PasswordStrengthView(password: password)
                    FVTextField(title: "Notes", text: $notes)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expiration du mot de passe").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        Picker("Expiration", selection: $expirationPolicy) {
                            ForEach(PasswordExpirationPolicy.allCases) { p in Text(p.label).tag(p) }
                        }.pickerStyle(.menu).foregroundStyle(FVColor.cyan)
                    }.fvGlass()

                    Toggle("Favori", isOn: $isFavorite).toggleStyle(.switch).fvGlass()
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Activer MFA", isOn: $mfaEnabled).toggleStyle(.switch)
                        if mfaEnabled { FVTextField(title: "Secret MFA", text: $mfaSecret, secure: true) }
                    }.fvGlass()

                    if isDuplicateEntry {
                        Text("Doublon détecté.").foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading).fvGlass()
                    }

                    FVButton(title: "Enregistrer") {
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
                            passwordLastChangedAt: password == entry.password ? entry.passwordLastChangedAt : Date()
                        )
                        vaultStore.updateEntry(updated)
                        dismiss()
                    }
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 26)
            }
            .navigationTitle("Modifier")
            .fvInlineNavTitle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() }.foregroundStyle(FVColor.cyan) } }
            .background(FVAnimatedBackground())
            .onAppear {
                title = entry.title; username = entry.username; password = entry.password
                website = entry.website; notes = entry.notes; mfaEnabled = entry.mfaEnabled
                mfaSecret = entry.mfaSecret; isFavorite = entry.isFavorite
                expirationPolicy = entry.expirationPolicy
            }
        }
    }
}
