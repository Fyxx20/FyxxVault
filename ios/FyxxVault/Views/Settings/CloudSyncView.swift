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
        var localizedName: String {
            switch self {
            case .signIn: return String(localized: "cloud.mode.signin")
            case .signUp: return String(localized: "cloud.mode.signup")
            }
        }
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
            .navigationTitle(String(localized: "cloud.nav.title"))
            .fvInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) { dismiss() }.foregroundStyle(FVColor.cyan)
                }
            }
            .background(FVAnimatedBackground())
            .confirmationDialog(String(localized: "cloud.dialog.signout.title"), isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button(String(localized: "cloud.dialog.signout.confirm"), role: .destructive) { syncService.signOut() }
                Button(String(localized: "settings.dialog.cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "cloud.dialog.signout.message"))
            }
        }
    }

    // MARK: - Authenticated View

    private var authenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 42))
                .foregroundStyle(FVColor.success)

            Text(String(localized: "cloud.authenticated.title"))
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
                FVSectionHeader(icon: "arrow.triangle.2.circlepath", title: String(localized: "cloud.section.sync"))

                HStack {
                    Text(String(localized: "settings.cloud.status"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(FVColor.mist)
                    Spacer()
                    switch syncService.state {
                    case .idle:
                        FVTag(text: String(localized: "cloud.status.ready"), color: FVColor.success)
                    case .syncing:
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text(String(localized: "cloud.status.syncing")).font(.system(size: 12)).foregroundStyle(FVColor.cyan)
                        }
                    case .error(let msg):
                        FVTag(text: msg, color: FVColor.danger)
                    case .disabled:
                        FVTag(text: String(localized: "cloud.status.disabled"), color: FVColor.mist)
                    }
                }

                if let lastSync = syncService.lastSyncDate {
                    HStack {
                        Text(String(localized: "cloud.last_sync"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(FVColor.mist)
                        Spacer()
                        Text(lastSync, style: .relative)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(FVColor.silver)
                    }
                }

                FVButton(title: String(localized: "cloud.button.sync_now")) {
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

            Button(String(localized: "cloud.button.signout")) { showSignOutConfirm = true }
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

            Text(String(localized: "cloud.unlock.title"))
                .font(FVFont.heading(20))
                .foregroundStyle(.white)

            if let email = syncService.cloudEmail {
                Text(email)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(FVColor.mist)
            }

            Text(String(localized: "cloud.unlock.description"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.mist.opacity(0.8))
                .multilineTextAlignment(.center)

            FVTextField(title: String(localized: "auth.field.master_password"), text: $masterPassword, secure: true)

            if !error.isEmpty {
                Text(error)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(FVColor.danger)
            }

            FVButton(title: isLoading ? String(localized: "cloud.unlock.unlocking") : String(localized: "cloud.unlock.button")) {
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

            Button(String(localized: "cloud.unlock.signout")) { syncService.signOut() }
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

            Text(String(localized: "cloud.auth.title"))
                .font(FVFont.heading(22))
                .foregroundStyle(.white)

            Text(String(localized: "cloud.auth.description"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.mist.opacity(0.8))
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                FVTag(text: "Zero-knowledge", color: FVColor.success)
                FVTag(text: String(localized: "cloud.auth.e2e_encrypted"), color: FVColor.violet)
            }

            Picker("Mode", selection: $mode) {
                ForEach(CloudAuthMode.allCases) { m in Text(m.localizedName).tag(m) }
            }
            .pickerStyle(.segmented)

            FVTextField(title: String(localized: "auth.field.email"), text: $email, keyboard: .email, contentType: .email)
            FVTextField(title: String(localized: "cloud.field.cloud_password"), text: $cloudPassword, secure: true)
            FVTextField(title: String(localized: "cloud.field.master_for_encryption"), text: $masterPassword, secure: true)

            if mode == .signUp {
                Text(String(localized: "cloud.auth.password_note"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.warning.opacity(0.8))
            }

            if !error.isEmpty {
                Text(error)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(FVColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            FVButton(title: isLoading ? String(localized: "cloud.auth.loading") : (mode == .signIn ? String(localized: "auth.button.login") : String(localized: "cloud.auth.create_account"))) {
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
