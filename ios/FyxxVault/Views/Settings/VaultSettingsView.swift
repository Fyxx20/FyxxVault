import SwiftUI
import UniformTypeIdentifiers

// MARK: - FVCollapsibleSection

struct FVCollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    var showProBadge: Bool = false
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // Header (tappable)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.system(size: 18))
                        .frame(width: 32)

                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    if showProBadge { FVProBadge() }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FVColor.smoke)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // Content (shown when expanded)
            if isExpanded {
                VStack(spacing: 12) {
                    content()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(FVColor.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isExpanded ? color.opacity(0.2) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - VaultSettingsView

struct VaultSettingsView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var vaultStore: VaultStore
    @ObservedObject var syncService: SyncService
    @ObservedObject var maskedEmailService: MaskedEmailService
    @ObservedObject var subscriptionService: SubscriptionService

    // MARK: - Sheet / Alert State

    @State private var showMaskedEmails = false
    @State private var showPaywall = false
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

    // MARK: - AppStorage Preferences

    @AppStorage("fyxxvault.autolock.enabled") private var autoLockEnabled = true
    @AppStorage("fyxxvault.autolock.minutes") private var autoLockMinutes = 2
    @AppStorage("fyxxvault.biometric.unlock") private var biometricUnlock = true
    @AppStorage("fyxxvault.clipboard.autoclear") private var clipboardAutoClear = true
    @AppStorage("fyxxvault.clipboard.clear.delay") private var clipboardClearDelay = 30
    @AppStorage("fyxxvault.hide.passwords.default") private var hidePasswordsByDefault = true
    @AppStorage("fyxxvault.hide.mfa.default") private var hideMFACodeByDefault = false
    @AppStorage("fyxxvault.haptics.enabled") private var hapticsEnabled = true
    @AppStorage("fyxxvault.screenshot.lock.enabled") private var screenshotLockEnabled = true

    // MARK: - Collapsible Section States

    @State private var subscriptionExpanded = false
    @State private var securityExpanded = false
    @State private var maskedEmailExpanded = false
    @State private var privacyExpanded = false
    @State private var dataExpanded = false
    @State private var backupExpanded = false
    @State private var advancedExpanded = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    profileCard

                    FVCollapsibleSection(
                        title: String(localized: "settings.section.subscription"),
                        icon: "crown.fill",
                        color: FVColor.gold,
                        isExpanded: $subscriptionExpanded
                    ) { subscriptionContent }

                    FVCollapsibleSection(
                        title: String(localized: "settings.section.security"),
                        icon: "lock.shield.fill",
                        color: FVColor.cyan,
                        isExpanded: $securityExpanded
                    ) { securityContent }

                    FVCollapsibleSection(
                        title: String(localized: "settings.section.masked_emails"),
                        icon: "envelope.badge.shield.half.filled.fill",
                        color: FVColor.rose,
                        showProBadge: true,
                        isExpanded: $maskedEmailExpanded
                    ) { maskedEmailContent }

                    FVCollapsibleSection(
                        title: String(localized: "settings.section.privacy"),
                        icon: "eye.slash.fill",
                        color: FVColor.success,
                        isExpanded: $privacyExpanded
                    ) { privacyContent }

                    FVCollapsibleSection(
                        title: String(localized: "settings.section.data"),
                        icon: "externaldrive.fill",
                        color: FVColor.warning,
                        isExpanded: $dataExpanded
                    ) { dataContent }

                    FVCollapsibleSection(
                        title: String(localized: "settings.section.backups"),
                        icon: "arrow.clockwise.icloud.fill",
                        color: FVColor.cyan,
                        isExpanded: $backupExpanded
                    ) { backupContent }

                    FVCollapsibleSection(
                        title: String(localized: "settings.section.advanced"),
                        icon: "gearshape.2.fill",
                        color: FVColor.smoke,
                        isExpanded: $advancedExpanded
                    ) { advancedContent }

                    changePasswordButton
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
            .sheet(isPresented: $showPaywall) { PaywallView(subscriptionService: subscriptionService) }
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

    // MARK: - Profile Card (always visible)

    private var profileCard: some View {
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

        return VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                // Left side: email, tags, plan
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(authManager.currentEmail)
                            .font(FVFont.body(14))
                            .foregroundStyle(FVColor.cyan)
                            .lineLimit(1)

                        syncStatusIcon
                    }

                    HStack(spacing: 6) {
                        FVTag(text: "\(score)/100 \u{2022} \(level)", color: scoreColor)

                        if subscriptionService.isProUser {
                            FVProBadge()
                        } else {
                            FVTag(text: String(localized: "paywall.free"), color: FVColor.smoke)
                        }
                    }

                    HStack(spacing: 6) {
                        FVTag(text: String(localized: "settings.header.accounts_count \(vaultStore.entries.count)"), color: FVColor.silver)
                        if authManager.hasRecoveryKey {
                            FVTag(text: String(localized: "settings.profile.recovery_key"), color: FVColor.violet)
                        }
                    }
                }

                Spacer()

                // Right side: small security gauge
                FVSecurityGauge(score: score, size: 50)
            }

            if !subscriptionService.isProUser {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 13))
                        Text(String(localized: "paywall.upgrade"))
                            .font(FVFont.title(14))
                    }
                    .foregroundStyle(FVColor.abyss)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(FVGradient.goldShimmer)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fvGlass()
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [FVColor.cyan.opacity(0.15), FVColor.violet.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: FVColor.cyan.opacity(0.06), radius: 20, y: 8)
    }

    // MARK: - Sync Status Icon

    @ViewBuilder
    private var syncStatusIcon: some View {
        switch syncService.state {
        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                .font(.system(size: 12))
                .foregroundStyle(FVColor.cyan)
                .symbolEffect(.rotate)
        case .error:
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.system(size: 12))
                .foregroundStyle(FVColor.warning)
        case .idle where syncService.isCloudAuthenticated:
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 12))
                .foregroundStyle(FVColor.success)
        default:
            EmptyView()
        }
    }

    // MARK: - Subscription Content

    @ViewBuilder
    private var subscriptionContent: some View {
        HStack {
            Text(String(localized: "paywall.current.plan"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.mist)
            Spacer()
            if subscriptionService.isProUser {
                FVProBadge()
            } else {
                FVTag(text: String(localized: "paywall.free"), color: FVColor.mist)
            }
        }

        if !subscriptionService.isProUser {
            Button(String(localized: "paywall.upgrade")) { showPaywall = true }
                .buttonStyle(FVSettingsButton(tint: FVColor.gold))
        }

        HStack(spacing: 10) {
            FVTag(text: String(localized: "settings.account.local"), color: FVColor.cyan)
            FVTag(text: String(localized: "settings.account.encryption_active"), color: FVColor.success)
        }
    }

    // MARK: - Security Content

    @ViewBuilder
    private var securityContent: some View {
        Toggle(String(localized: "settings.security.auto_lock"), isOn: $autoLockEnabled)
            .toggleStyle(.switch)
        if autoLockEnabled {
            Stepper(String(localized: "settings.security.auto_lock_delay \(autoLockMinutes)"), value: $autoLockMinutes, in: 1...15)
                .foregroundStyle(.white.opacity(0.85))
        }
        Toggle(String(localized: "settings.security.biometric_unlock"), isOn: $biometricUnlock)
            .toggleStyle(.switch)
        Toggle(String(localized: "settings.security.screenshot_lock"), isOn: $screenshotLockEnabled)
            .toggleStyle(.switch)
        Toggle(String(localized: "settings.security.clipboard_clear"), isOn: $clipboardAutoClear)
            .toggleStyle(.switch)
        if clipboardAutoClear {
            Picker(String(localized: "settings.security.clear_delay"), selection: $clipboardClearDelay) {
                Text("15s").tag(15); Text("30s").tag(30); Text("60s").tag(60)
            }.pickerStyle(.segmented)
        }
        Text(String(localized: "settings.security.panic_note"))
            .font(FVFont.caption(11))
            .foregroundStyle(FVColor.mist.opacity(0.75))
    }

    // MARK: - Masked Email Content

    @ViewBuilder
    private var maskedEmailContent: some View {
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
        Button(String(localized: "settings.masked.button \(maskedEmailService.aliases.count)")) {
            if subscriptionService.isProUser {
                showMaskedEmails = true
            } else {
                showPaywall = true
            }
        }
        .buttonStyle(FVSettingsButton(tint: FVColor.cyan))

        Text(String(localized: "settings.masked.description"))
            .font(FVFont.caption(11))
            .foregroundStyle(FVColor.mist.opacity(0.75))
    }

    // MARK: - Privacy Content

    @ViewBuilder
    private var privacyContent: some View {
        Toggle(String(localized: "settings.privacy.hide_passwords"), isOn: $hidePasswordsByDefault)
            .toggleStyle(.switch)
        Toggle(String(localized: "settings.privacy.hide_mfa"), isOn: $hideMFACodeByDefault)
            .toggleStyle(.switch)
        Toggle(String(localized: "settings.privacy.haptic_feedback"), isOn: $hapticsEnabled)
            .toggleStyle(.switch)
        Button(String(localized: "settings.privacy.reset_visual")) { showResetPrefsConfirm = true }
            .buttonStyle(FVSettingsButton(tint: FVColor.silver))
    }

    // MARK: - Data Content

    @ViewBuilder
    private var dataContent: some View {
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

    // MARK: - Backup Content

    @ViewBuilder
    private var backupContent: some View {
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

    // MARK: - Advanced Content

    @ViewBuilder
    private var advancedContent: some View {
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

    // MARK: - Change Password Button

    private var changePasswordButton: some View {
        Button { showChangePassword = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(FVColor.cyan)
                Text(String(localized: "settings.account.change_password"))
                    .font(FVFont.title(15))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FVColor.smoke)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(FVColor.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(FVColor.cyan.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logout Button

    private var logoutButton: some View {
        Button { showLogoutSheet = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15))
                    .foregroundStyle(FVColor.danger)
                Text(String(localized: "settings.button.logout"))
                    .font(FVFont.title(15))
                    .foregroundStyle(FVColor.danger)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(FVColor.danger.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(FVColor.danger.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

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
