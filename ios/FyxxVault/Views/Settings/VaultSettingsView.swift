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
            .navigationTitle(String(localized: "settings.nav.title"))
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
            .confirmationDialog(String(localized: "settings.dialog.empty_trash.title"), isPresented: $showEmptyTrashConfirm, titleVisibility: .visible) {
                Button(String(localized: "settings.dialog.empty_trash.confirm"), role: .destructive) { vaultStore.emptyTrash() }
                Button(String(localized: "settings.dialog.cancel"), role: .cancel) {}
            } message: { Text(String(localized: "settings.dialog.empty_trash.message")) }
            .confirmationDialog(String(localized: "settings.dialog.clear_log.title"), isPresented: $showClearLogConfirm, titleVisibility: .visible) {
                Button(String(localized: "settings.dialog.clear_log.confirm"), role: .destructive) { vaultStore.clearActivityLog() }
                Button(String(localized: "settings.dialog.cancel"), role: .cancel) {}
            } message: { Text(String(localized: "settings.dialog.clear_log.message")) }
            .confirmationDialog(String(localized: "settings.dialog.rotate_key.title"), isPresented: $showRotateKeyConfirm, titleVisibility: .visible) {
                Button(String(localized: "settings.dialog.rotate_key.confirm"), role: .destructive) { vaultStore.rotateVaultKeyNow(); alertMessage = String(localized: "settings.alert.key_rotated"); showAlert = true }
                Button(String(localized: "settings.dialog.cancel"), role: .cancel) {}
            } message: { Text(String(localized: "settings.dialog.rotate_key.message")) }
            .confirmationDialog(String(localized: "settings.dialog.reset_prefs.title"), isPresented: $showResetPrefsConfirm, titleVisibility: .visible) {
                Button(String(localized: "settings.dialog.reset_prefs.confirm"), role: .destructive) { resetPreferencesToDefault() }
                Button(String(localized: "settings.dialog.cancel"), role: .cancel) {}
            } message: { Text(String(localized: "settings.dialog.reset_prefs.message")) }
            .confirmationDialog(String(localized: "settings.dialog.csv_export.title"), isPresented: $showCSVExportWarning, titleVisibility: .visible) {
                Button(String(localized: "settings.dialog.csv_export.confirm"), role: .destructive) { performCSVExport() }
                Button(String(localized: "settings.dialog.cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "settings.dialog.csv_export.message"))
            }
            .alert(String(localized: "settings.alert.info"), isPresented: $showAlert) { Button("OK", role: .cancel) {} } message: { Text(alertMessage) }
            .alert(String(localized: "settings.alert.backup_passphrase.title"), isPresented: $showExportPrompt) {
                SecureField(String(localized: "settings.alert.backup_passphrase.placeholder"), text: $backupPassphrase)
                Button(String(localized: "settings.alert.backup_passphrase.export")) {
                    do {
                        let data = try vaultStore.exportBackup(passphrase: backupPassphrase)
                        exportDocument = BackupFileDocument(data: data)
                        showFileExporter = true
                    } catch { alertMessage = String(localized: "settings.alert.export_failed"); showAlert = true }
                    backupPassphrase = ""
                }
                Button(String(localized: "settings.dialog.cancel"), role: .cancel) {}
            } message: { Text(String(localized: "settings.alert.backup_passphrase.message")) }
            .alert(String(localized: "settings.alert.import_passphrase.title"), isPresented: $showImportPrompt) {
                SecureField(String(localized: "settings.alert.import_passphrase.placeholder"), text: $backupPassphrase)
                Button(String(localized: "settings.alert.import_passphrase.import")) {
                    guard let data = pendingImportData else { return }
                    do { try vaultStore.importBackup(data, passphrase: backupPassphrase) }
                    catch { alertMessage = String(localized: "settings.alert.import_failed"); showAlert = true }
                    pendingImportData = nil; backupPassphrase = ""
                }
                Button(String(localized: "settings.dialog.cancel"), role: .cancel) { pendingImportData = nil; backupPassphrase = "" }
            } message: { Text(String(localized: "settings.alert.import_passphrase.message")) }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [UTType.fyxxVaultBackup], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first, let data = try? Data(contentsOf: url) else { return }
                    pendingImportData = data; showImportPrompt = true
                case .failure: alertMessage = String(localized: "settings.alert.file_read_failed"); showAlert = true
                }
            }
            .fileExporter(isPresented: $showFileExporter, document: exportDocument, contentType: .fyxxVaultBackup, defaultFilename: "FyxxVault-Backup-\(Int(Date().timeIntervalSince1970))") { result in
                if case .failure = result { alertMessage = String(localized: "settings.alert.export_cancelled"); showAlert = true }
            }
            .background(FVAnimatedBackground())
            .tint(FVColor.cyan)
        }
    }

    private var headerCard: some View {
        let audit = vaultStore.securityAudit
        let score = audit.score
        let level: String = {
            if score < 40 { return String(localized: "settings.score.critical") }
            if score < 70 { return String(localized: "settings.score.fragile") }
            if score < 85 { return String(localized: "settings.score.fair") }
            if score < 95 { return String(localized: "settings.score.solid") }
            return String(localized: "settings.score.excellent")
        }()

        let scoreColor: Color = score >= 85 ? FVColor.success : (score >= 70 ? FVColor.warning : FVColor.danger)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: "settings.header.title"))
                        .font(FVFont.heading(28))
                        .foregroundStyle(.white)
                    Text(String(localized: "settings.header.subtitle"))
                        .font(FVFont.caption(12))
                        .foregroundStyle(FVColor.mist.opacity(0.9))
                }
                Spacer()

                // Prominent security score
                FVSecurityGauge(score: score, size: 72)
            }

            // Divider
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)

            HStack(spacing: 8) {
                FVTag(text: authManager.currentEmail, color: FVColor.cyan)
                if authManager.hasRecoveryKey {
                    FVTag(text: "Recovery Key", color: FVColor.violet)
                }
                FVTag(text: String(localized: "settings.header.accounts_count \(vaultStore.entries.count)"), color: FVColor.silver)
            }

            FVTag(text: "\(score)/100 \u{2022} \(level)", color: scoreColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fvGlass()
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "person.crop.circle", title: String(localized: "settings.section.account"))
            Button(String(localized: "settings.account.change_password")) { showChangePassword = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            HStack(spacing: 10) {
                FVTag(text: String(localized: "settings.account.local"), color: FVColor.cyan)
                FVTag(text: String(localized: "settings.account.encryption_active"), color: FVColor.success)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var cloudSyncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "cloud.fill", title: String(localized: "settings.section.cloud_sync"))
            HStack {
                Text(String(localized: "settings.cloud.status"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.mist)
                Spacer()
                if syncService.isCloudAuthenticated {
                    FVTag(text: String(localized: "settings.cloud.connected"), color: FVColor.success)
                } else if syncService.cloudEmail != nil {
                    FVTag(text: String(localized: "settings.cloud.locked"), color: FVColor.warning)
                } else {
                    FVTag(text: String(localized: "settings.cloud.not_configured"), color: FVColor.mist)
                }
            }
            if let email = syncService.cloudEmail {
                Text(email)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(FVColor.cyan.opacity(0.8))
            }
            Button(String(localized: "settings.cloud.configure")) { showCloudSync = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Text(String(localized: "settings.cloud.zero_knowledge_note"))
                .font(FVFont.caption(11))
                .foregroundStyle(FVColor.mist.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var maskedEmailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "envelope.badge.shield.half.filled", title: String(localized: "settings.section.masked_emails"))
            HStack {
                Text(String(localized: "settings.cloud.status"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.mist)
                Spacer()
                if maskedEmailService.isConfigured {
                    FVTag(text: String(localized: "settings.masked.alias_count \(maskedEmailService.aliases.count)"), color: FVColor.success)
                } else {
                    FVTag(text: String(localized: "settings.cloud.not_configured"), color: FVColor.mist)
                }
            }
            Button(String(localized: "settings.masked.button \(maskedEmailService.aliases.count)")) { showMaskedEmails = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Text(String(localized: "settings.masked.description"))
                .font(FVFont.caption(11))
                .foregroundStyle(FVColor.mist.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "lock.shield", title: String(localized: "settings.section.security"))
            Toggle(String(localized: "settings.security.auto_lock"), isOn: $autoLockEnabled).toggleStyle(.switch)
            if autoLockEnabled {
                Stepper(String(localized: "settings.security.auto_lock_delay \(autoLockMinutes)"), value: $autoLockMinutes, in: 1...15)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Toggle(String(localized: "settings.security.biometric_unlock"), isOn: $biometricUnlock).toggleStyle(.switch)
            Toggle(String(localized: "settings.security.screenshot_lock"), isOn: $screenshotLockEnabled).toggleStyle(.switch)
            Toggle(String(localized: "settings.security.clipboard_clear"), isOn: $clipboardAutoClear).toggleStyle(.switch)
            if clipboardAutoClear {
                Picker(String(localized: "settings.security.clear_delay"), selection: $clipboardClearDelay) {
                    Text("15s").tag(15); Text("30s").tag(30); Text("60s").tag(60)
                }.pickerStyle(.segmented)
            }
            Text(String(localized: "settings.security.panic_note"))
                .font(FVFont.caption(11))
                .foregroundStyle(FVColor.mist.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "eye.slash", title: String(localized: "settings.section.privacy"))
            Toggle(String(localized: "settings.privacy.hide_passwords"), isOn: $hidePasswordsByDefault).toggleStyle(.switch)
            Toggle(String(localized: "settings.privacy.hide_mfa"), isOn: $hideMFACodeByDefault).toggleStyle(.switch)
            Toggle(String(localized: "settings.privacy.haptic_feedback"), isOn: $hapticsEnabled).toggleStyle(.switch)
            Button(String(localized: "settings.privacy.reset_visual")) { showResetPrefsConfirm = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.silver))
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "externaldrive", title: String(localized: "settings.section.data"))
            Button(String(localized: "settings.data.trash \(vaultStore.trashEntries.count)")) { showTrash = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Button(String(localized: "settings.data.activity_log \(vaultStore.activityLog.count)")) { showActivityLog = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Button(String(localized: "settings.data.reorder")) { showReorder = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Button(String(localized: "settings.data.purge_log")) { showClearLogConfirm = true }
                .buttonStyle(FVSettingsButton(tint: .orange.opacity(0.9)))
            Button(String(localized: "settings.data.empty_trash")) { showEmptyTrashConfirm = true }
                .buttonStyle(FVSettingsButton(tint: .red.opacity(0.9)))
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "archivebox", title: String(localized: "settings.section.backups"))
            Button(String(localized: "settings.backup.export_encrypted")) { showExportPrompt = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Button(String(localized: "settings.backup.import")) { showFileImporter = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Button(String(localized: "settings.backup.import_csv")) { showImportCSV = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
            Text(String(localized: "settings.backup.format_note"))
                .font(FVFont.caption(11))
                .foregroundStyle(FVColor.mist.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var advancedSecuritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FVSectionHeader(icon: "gearshape.2", title: String(localized: "settings.section.advanced"))
            Button(String(localized: "settings.advanced.rotate_key")) { showRotateKeyConfirm = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.violet))
            Button(String(localized: "settings.advanced.export_csv")) { pendingCSVType = 0; showCSVExportWarning = true }
                .buttonStyle(FVSettingsButton(tint: .orange.opacity(0.85)))
            Button(String(localized: "settings.advanced.export_csv_bitwarden")) { pendingCSVType = 1; showCSVExportWarning = true }
                .buttonStyle(FVSettingsButton(tint: .orange.opacity(0.85)))
            Button(String(localized: "settings.advanced.export_csv_1password")) { pendingCSVType = 2; showCSVExportWarning = true }
                .buttonStyle(FVSettingsButton(tint: .orange.opacity(0.85)))
            Text(String(localized: "settings.advanced.csv_warning"))
                .font(FVFont.caption(11))
                .foregroundStyle(FVColor.warning.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }

    private var logoutButton: some View {
        Button { showLogoutSheet = true } label: {
            Label(String(localized: "settings.button.logout"), systemImage: "rectangle.portrait.and.arrow.right")
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
        alertMessage = String(localized: "settings.alert.csv_copied")
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
        alertMessage = String(localized: "settings.alert.prefs_reset")
        showAlert = true
    }
}
