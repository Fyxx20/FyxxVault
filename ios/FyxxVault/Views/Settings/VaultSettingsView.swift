import SwiftUI
import UniformTypeIdentifiers

struct VaultSettingsView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var vaultStore: VaultStore
    @ObservedObject var syncService: SyncService
    @ObservedObject var maskedEmailService: MaskedEmailService

    @State private var showMaskedEmails = false
    @State private var showCloudSync = false
    @State private var showTrash = false
    @State private var showActivityLog = false
    @State private var showReorder = false
    @State private var showChangePassword = false
    @State private var showEmptyTrashConfirm = false
    @State private var showClearLogConfirm = false
    @State private var showRotateKeyConfirm = false
    @State private var showResetPrefsConfirm = false
    @State private var showLogoutSheet = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showExportPrompt = false
    @State private var showImportPrompt = false
    @State private var backupPassphrase = ""
    @State private var pendingImportData: Data?
    @State private var exportDocument: BackupFileDocument?
    @State private var showFileImporter = false
    @State private var showFileExporter = false
    @State private var showCSVExportWarning = false
    @State private var pendingCSVType = 0
    @State private var showImportCSV = false

    @AppStorage("fyxxvault.autolock.enabled") private var autoLockEnabled = true
    @AppStorage("fyxxvault.autolock.minutes") private var autoLockMinutes = 2
    @AppStorage("fyxxvault.biometric.unlock") private var biometricUnlock = true
    @AppStorage("fyxxvault.clipboard.autoclear") private var clipboardAutoClear = true
    @AppStorage("fyxxvault.clipboard.clear.delay") private var clipboardClearDelay = 30
    @AppStorage("fyxxvault.hide.passwords.default") private var hidePasswordsByDefault = true
    @AppStorage("fyxxvault.hide.mfa.default") private var hideMFACodeByDefault = false
    @AppStorage("fyxxvault.haptics.enabled") private var hapticsEnabled = true
    @AppStorage("fyxxvault.screenshot.lock.enabled") private var screenshotLockEnabled = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    accountSection
                    cloudSyncSection
                    maskedEmailSection
                    securitySection
                    privacySection
                    dataSection
                    backupSection
                    advancedSecuritySection
                    logoutButton
                    Color.clear.frame(height: 130)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Paramètres")
            .fvInlineNavTitle()
            .sheet(isPresented: $showTrash) { VaultTrashView(vaultStore: vaultStore) }
            .sheet(isPresented: $showActivityLog) { ActivityLogView(vaultStore: vaultStore) }
            .sheet(isPresented: $showReorder) { VaultReorderView(vaultStore: vaultStore) }
            .sheet(isPresented: $showChangePassword) { ChangePasswordView(authManager: authManager) }
            .sheet(isPresented: $showImportCSV) { ImportView(vaultStore: vaultStore) }
            .sheet(isPresented: $showMaskedEmails) { MaskedEmailView(maskedEmailService: maskedEmailService) }
            .sheet(isPresented: $showCloudSync) { CloudSyncView(syncService: syncService, vaultStore: vaultStore) }
            .sheet(isPresented: $showLogoutSheet) {
                LogoutConfirmSheet(
                    onCancel: { showLogoutSheet = false },
                    onConfirm: {
                        showLogoutSheet = false
                        authManager.logout()
                    }
                )
                .presentationDetents([.height(285)])
                .presentationDragIndicator(.visible)
            }
            .confirmationDialog("Vider la corbeille ?", isPresented: $showEmptyTrashConfirm, titleVisibility: .visible) {
                Button("Vider", role: .destructive) { vaultStore.emptyTrash() }
                Button("Annuler", role: .cancel) {}
            } message: { Text("Tous les éléments supprimés seront effacés définitivement.") }
            .confirmationDialog("Purger le journal d'activité ?", isPresented: $showClearLogConfirm, titleVisibility: .visible) {
                Button("Purger", role: .destructive) { vaultStore.clearActivityLog() }
                Button("Annuler", role: .cancel) {}
            } message: { Text("Cette action est irréversible.") }
            .confirmationDialog("Forcer une rotation de clé ?", isPresented: $showRotateKeyConfirm, titleVisibility: .visible) {
                Button("Lancer", role: .destructive) { vaultStore.rotateVaultKeyNow(); alertMessage = "Clé du coffre renouvelée."; showAlert = true }
                Button("Annuler", role: .cancel) {}
            } message: { Text("Une nouvelle clé AES-256 sera générée pour le coffre local.") }
            .confirmationDialog("Réinitialiser les préférences ?", isPresented: $showResetPrefsConfirm, titleVisibility: .visible) {
                Button("Réinitialiser", role: .destructive) { resetPreferencesToDefault() }
                Button("Annuler", role: .cancel) {}
            } message: { Text("Seules les préférences d'interface et confidentialité seront réinitialisées.") }
            .confirmationDialog("Attention — Export en clair", isPresented: $showCSVExportWarning, titleVisibility: .visible) {
                Button("Exporter quand même", role: .destructive) { performCSVExport() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("L'export CSV contient tous tes mots de passe en texte clair. Ne l'envoie pas par email ou messagerie non chiffrée. Supprime-le après usage.")
            }
            .alert("Info", isPresented: $showAlert) { Button("OK", role: .cancel) {} } message: { Text(alertMessage) }
            .alert("Phrase secrète backup", isPresented: $showExportPrompt) {
                SecureField("Au moins 10 caractères", text: $backupPassphrase)
                Button("Exporter") {
                    do {
                        let data = try vaultStore.exportBackup(passphrase: backupPassphrase)
                        exportDocument = BackupFileDocument(data: data)
                        showFileExporter = true
                    } catch { alertMessage = "Échec export. Vérifie la phrase secrète."; showAlert = true }
                    backupPassphrase = ""
                }
                Button("Annuler", role: .cancel) {}
            } message: { Text("Cette phrase sera nécessaire pour restaurer le backup.") }
            .alert("Phrase secrète import", isPresented: $showImportPrompt) {
                SecureField("Phrase secrète", text: $backupPassphrase)
                Button("Importer") {
                    guard let data = pendingImportData else { return }
                    do { try vaultStore.importBackup(data, passphrase: backupPassphrase) }
                    catch { alertMessage = "Import refusé (phrase invalide ou fichier altéré)."; showAlert = true }
                    pendingImportData = nil; backupPassphrase = ""
                }
                Button("Annuler", role: .cancel) { pendingImportData = nil; backupPassphrase = "" }
            } message: { Text("Entre la phrase utilisée pendant l'export.") }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [UTType.fyxxVaultBackup], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first, let data = try? Data(contentsOf: url) else { return }
                    pendingImportData = data; showImportPrompt = true
                case .failure: alertMessage = "Impossible de lire le fichier."; showAlert = true
                }
            }
            .fileExporter(isPresented: $showFileExporter, document: exportDocument, contentType: .fyxxVaultBackup, defaultFilename: "FyxxVault-Backup-\(Int(Date().timeIntervalSince1970))") { result in
                if case .failure = result { alertMessage = "Export annulé ou échoué."; showAlert = true }
            }
            .background(FVAnimatedBackground())
            .tint(FVColor.cyan)
        }
    }

    private var headerCard: some View {
        let audit = vaultStore.securityAudit
        let score = audit.score
        let level = score < 40 ? "Critique" : (score < 70 ? "Fragile" : (score < 85 ? "Correct" : (score < 95 ? "Solide" : "Excellent")))

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Préférences FyxxVault")
                        .font(FVFont.heading(30))
                        .foregroundStyle(.white)
                    Text("Centre de contrôle du coffre")
                        .font(FVFont.caption(12))
                        .foregroundStyle(FVColor.mist.opacity(0.9))
                }
                Spacer()
                FVTag(text: "\(score)/100 • \(level)", color: score >= 85 ? FVColor.success : (score >= 70 ? FVColor.warning : FVColor.danger))
            }

            HStack(spacing: 8) {
                FVTag(text: authManager.currentEmail, color: FVColor.cyan)
                if authManager.hasRecoveryKey {
                    FVTag(text: "Recovery Key", color: FVColor.violet)
                }
                FVTag(text: "\(vaultStore.entries.count) comptes", color: FVColor.silver)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fvGlass()
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "person.crop.circle", title: "COMPTE")
            Button("Changer le mot de passe maître") { showChangePassword = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            HStack(spacing: 10) {
                FVTag(text: "Compte local", color: FVColor.cyan)
                FVTag(text: "Chiffrement actif", color: FVColor.success)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var cloudSyncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "cloud.fill", title: "SYNCHRONISATION CLOUD")
            HStack {
                Text("Statut")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.mist)
                Spacer()
                if syncService.isCloudAuthenticated {
                    FVTag(text: "Connecté", color: FVColor.success)
                } else if syncService.cloudEmail != nil {
                    FVTag(text: "Verrouillé", color: FVColor.warning)
                } else {
                    FVTag(text: "Non configuré", color: FVColor.mist)
                }
            }
            if let email = syncService.cloudEmail {
                Text(email)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(FVColor.cyan.opacity(0.8))
            }
            Button("Configurer la synchronisation cloud") { showCloudSync = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Text("Chiffrement zero-knowledge : le serveur ne voit que des données chiffrées.")
                .font(FVFont.caption(11))
                .foregroundStyle(FVColor.mist.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var maskedEmailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "envelope.badge.shield.half.filled", title: "EMAILS MASQUÉS")
            HStack {
                Text("Statut")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.mist)
                Spacer()
                if maskedEmailService.isConfigured {
                    FVTag(text: "\(maskedEmailService.aliases.count) alias", color: FVColor.success)
                } else {
                    FVTag(text: "Non configuré", color: FVColor.mist)
                }
            }
            Button("Emails masqués (\(maskedEmailService.aliases.count))") { showMaskedEmails = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Text("Protège ton vrai email avec des alias uniques via addy.io.")
                .font(FVFont.caption(11))
                .foregroundStyle(FVColor.mist.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "lock.shield", title: "SÉCURITÉ")
            Toggle("Verrouillage automatique", isOn: $autoLockEnabled).toggleStyle(.switch)
            if autoLockEnabled {
                Stepper("Délai auto-lock: \(autoLockMinutes) min", value: $autoLockMinutes, in: 1...15)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Toggle("Déverrouillage biométrique", isOn: $biometricUnlock).toggleStyle(.switch)
            Toggle("Verrouiller en cas de capture d'écran", isOn: $screenshotLockEnabled).toggleStyle(.switch)
            Toggle("Effacer le presse-papier après copie", isOn: $clipboardAutoClear).toggleStyle(.switch)
            if clipboardAutoClear {
                Picker("Délai effacement", selection: $clipboardClearDelay) {
                    Text("15s").tag(15); Text("30s").tag(30); Text("60s").tag(60)
                }.pickerStyle(.segmented)
            }
            Text("5 échecs biométriques déclenchent le mode panic.")
                .font(FVFont.caption(11))
                .foregroundStyle(FVColor.mist.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "eye.slash", title: "CONFIDENTIALITÉ")
            Toggle("Masquer les mots de passe par défaut", isOn: $hidePasswordsByDefault).toggleStyle(.switch)
            Toggle("Masquer les codes MFA par défaut", isOn: $hideMFACodeByDefault).toggleStyle(.switch)
            Toggle("Retour haptique", isOn: $hapticsEnabled).toggleStyle(.switch)
            Button("Réinitialiser les préférences visuelles") { showResetPrefsConfirm = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.silver))
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "externaldrive", title: "DONNÉES")
            Button("Ouvrir la corbeille (\(vaultStore.trashEntries.count))") { showTrash = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Button("Journal d'activité (\(vaultStore.activityLog.count))") { showActivityLog = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Button("Réorganiser les entrées") { showReorder = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Button("Purger le journal d'activité local") { showClearLogConfirm = true }
                .buttonStyle(FVSettingsButton(tint: .orange.opacity(0.9)))
            Button("Vider la corbeille") { showEmptyTrashConfirm = true }
                .buttonStyle(FVSettingsButton(tint: .red.opacity(0.9)))
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "archivebox", title: "SAUVEGARDES")
            Button("Exporter une sauvegarde chiffrée (recommandé)") { showExportPrompt = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Button("Importer une sauvegarde") { showFileImporter = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Button("Importer depuis CSV (Bitwarden / 1Password)") { showImportCSV = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Text("Le format .fyxx.backup est chiffré et vérifié en intégrité.")
                .font(FVFont.caption(11))
                .foregroundStyle(FVColor.mist.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var advancedSecuritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "gearshape.2", title: "AVANCÉ")
            Button("Rotation manuelle de la clé du coffre") { showRotateKeyConfirm = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.violet))
            Button("Exporter CSV (données sensibles non chiffrées)") { pendingCSVType = 0; showCSVExportWarning = true }
                .buttonStyle(FVSettingsButton(tint: .orange.opacity(0.85)))
            Button("Exporter CSV Bitwarden (données sensibles)") { pendingCSVType = 1; showCSVExportWarning = true }
                .buttonStyle(FVSettingsButton(tint: .orange.opacity(0.85)))
            Button("Exporter CSV 1Password (données sensibles)") { pendingCSVType = 2; showCSVExportWarning = true }
                .buttonStyle(FVSettingsButton(tint: .orange.opacity(0.85)))
            Text("Les exports CSV doivent être supprimés juste après import.")
                .font(FVFont.caption(11))
                .foregroundStyle(FVColor.warning.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var logoutButton: some View {
        Button { showLogoutSheet = true } label: {
            Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                .font(FVFont.title(17))
                .frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(FVSettingsButton(tint: .red.opacity(0.9)))
    }

    private func performCSVExport() {
        let csv: String
        switch pendingCSVType {
        case 0: csv = vaultStore.exportCSV()
        case 1: csv = vaultStore.exportBitwardenCSV()
        default: csv = vaultStore.exportOnePasswordCSV()
        }
        alertMessage = "CSV copié dans le presse-papier. Supprimez le fichier après usage."
        showAlert = true
        ClipboardService.copy(csv)
    }

    private func resetPreferencesToDefault() {
        autoLockEnabled = true
        autoLockMinutes = 2
        biometricUnlock = true
        clipboardAutoClear = true
        clipboardClearDelay = 30
        hidePasswordsByDefault = true
        hideMFACodeByDefault = false
        hapticsEnabled = true
        screenshotLockEnabled = true
        alertMessage = "Préférences réinitialisées."
        showAlert = true
    }
}
