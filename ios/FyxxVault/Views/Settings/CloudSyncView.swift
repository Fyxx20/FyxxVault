import SwiftUI

struct CloudSyncView: View {
    @ObservedObject var syncService: SyncService
    @ObservedObject var vaultStore: VaultStore
    @Environment(\.dismiss) private var dismiss

    @State private var mode: CloudAuthMode = .signIn
    @State private var email = ""
    @State private var cloudPassword = ""
    @State private var masterPassword = ""
    @State private var error = ""
    @State private var isLoading = false
    @State private var showSignOutConfirm = false

    enum CloudAuthMode: String, CaseIterable, Identifiable {
        case signIn = "Connexion"
        case signUp = "Inscription"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if syncService.isCloudAuthenticated {
                        authenticatedView
                    } else if syncService.cloudEmail != nil {
                        // Has session but needs master password unlock
                        unlockView
                    } else {
                        authFormView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .navigationTitle("Sync Cloud")
            .fvInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundStyle(FVColor.cyan)
                }
            }
            .background(FVAnimatedBackground())
            .confirmationDialog("Se déconnecter du cloud ?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Déconnecter", role: .destructive) { syncService.signOut() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Les données locales seront conservées. La synchronisation sera désactivée.")
            }
        }
    }

    // MARK: - Authenticated View

    private var authenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 42))
                .foregroundStyle(FVColor.success)

            Text("Cloud connecté")
                .font(FVFont.heading(22))
                .foregroundStyle(.white)

            if let email = syncService.cloudEmail {
                FVTag(text: email, color: FVColor.cyan)
            }

            HStack(spacing: 12) {
                FVTag(text: "Zero-knowledge", color: FVColor.success)
                FVTag(text: "AES-256-GCM", color: FVColor.violet)
            }

            // Sync status
            VStack(alignment: .leading, spacing: 8) {
                FVSectionHeader(icon: "arrow.triangle.2.circlepath", title: "SYNCHRONISATION")

                HStack {
                    Text("Statut")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(FVColor.mist)
                    Spacer()
                    switch syncService.state {
                    case .idle:
                        FVTag(text: "Prêt", color: FVColor.success)
                    case .syncing:
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("Synchronisation...").font(.system(size: 12)).foregroundStyle(FVColor.cyan)
                        }
                    case .error(let msg):
                        FVTag(text: msg, color: FVColor.danger)
                    case .disabled:
                        FVTag(text: "Désactivé", color: FVColor.mist)
                    }
                }

                if let lastSync = syncService.lastSyncDate {
                    HStack {
                        Text("Dernière sync")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(FVColor.mist)
                        Spacer()
                        Text(lastSync, style: .relative)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(FVColor.silver)
                    }
                }

                FVButton(title: "Synchroniser maintenant") {
                    Task {
                        do {
                            let merged = try await syncService.sync(localEntries: vaultStore.entries)
                            vaultStore.replaceEntries(merged)
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
            }
            .fvGlass()

            Button("Se déconnecter du cloud") { showSignOutConfirm = true }
                .buttonStyle(FVSettingsButton(tint: .red.opacity(0.9)))
        }
        .fvGlass()
    }

    // MARK: - Unlock View (has session, needs master password)

    private var unlockView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 42))
                .foregroundStyle(FVColor.violet)

            Text("Déverrouiller le cloud")
                .font(FVFont.heading(20))
                .foregroundStyle(.white)

            if let email = syncService.cloudEmail {
                Text(email)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(FVColor.mist)
            }

            Text("Entre ton mot de passe maître pour déchiffrer tes données cloud.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.mist.opacity(0.8))
                .multilineTextAlignment(.center)

            FVTextField(title: "Mot de passe maître", text: $masterPassword, secure: true)

            if !error.isEmpty {
                Text(error)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(FVColor.danger)
            }

            FVButton(title: isLoading ? "Déverrouillage..." : "Déverrouiller") {
                guard !masterPassword.isEmpty else { return }
                isLoading = true
                error = ""
                Task {
                    do {
                        try await syncService.unlockCloud(masterPassword: masterPassword)
                        masterPassword = ""
                    } catch {
                        self.error = error.localizedDescription
                    }
                    isLoading = false
                }
            }

            Button("Se déconnecter") { syncService.signOut() }
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(FVColor.danger.opacity(0.8))
        }
        .fvGlass()
    }

    // MARK: - Auth Form

    private var authFormView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 42))
                .foregroundStyle(FVColor.cyan)

            Text("Synchronisation Cloud")
                .font(FVFont.heading(22))
                .foregroundStyle(.white)

            Text("Tes données sont chiffrées localement avant d'être envoyées. Le serveur ne voit que des blobs chiffrés.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.mist.opacity(0.8))
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                FVTag(text: "Zero-knowledge", color: FVColor.success)
                FVTag(text: "E2E chiffré", color: FVColor.violet)
            }

            Picker("Mode", selection: $mode) {
                ForEach(CloudAuthMode.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)

            FVTextField(title: "Email", text: $email, keyboard: .email, contentType: .email)
            FVTextField(title: "Mot de passe cloud", text: $cloudPassword, secure: true)
            FVTextField(title: "Mot de passe maître (pour le chiffrement)", text: $masterPassword, secure: true)

            if mode == .signUp {
                Text("Le mot de passe cloud sert à l'authentification Supabase. Le mot de passe maître sert au chiffrement de tes données. Ils peuvent être différents.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.warning.opacity(0.8))
            }

            if !error.isEmpty {
                Text(error)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(FVColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            FVButton(title: isLoading ? "Chargement..." : (mode == .signIn ? "Se connecter" : "Créer un compte")) {
                guard !email.isEmpty, !cloudPassword.isEmpty, !masterPassword.isEmpty else { return }
                isLoading = true
                error = ""
                Task {
                    do {
                        if mode == .signUp {
                            try await syncService.signUpWithEmail(email: email, password: cloudPassword, masterPassword: masterPassword)
                        } else {
                            try await syncService.signInWithEmail(email: email, password: cloudPassword, masterPassword: masterPassword)
                        }
                        email = ""
                        cloudPassword = ""
                        masterPassword = ""
                    } catch {
                        self.error = error.localizedDescription
                    }
                    isLoading = false
                }
            }
        }
        .fvGlass()
    }
}
