import SwiftUI
import CryptoKit
import Security
import Combine
import LocalAuthentication
import AVFoundation
import UniformTypeIdentifiers
import CommonCrypto
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Root View

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @StateObject private var vaultStore = VaultStore()
    @StateObject private var appLock = AppLockManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            FVAnimatedBackground()

            Group {
                switch authManager.phase {
                case .auth:
                    AuthView(authManager: authManager)
                case .onboarding:
                    OnboardingView(authManager: authManager)
                case .vault:
                    if appLock.isLocked {
                        VaultLockView(appLock: appLock, authManager: authManager)
                    } else {
                        VaultDashboardView(authManager: authManager, vaultStore: vaultStore)
                    }
                }
            }
            .padding(.horizontal, authManager.phase == .vault ? 10 : 20)
            .padding(.vertical, authManager.phase == .vault ? 0 : 28)

            // Screenshot detection overlay
            if appLock.screenshotDetected {
                Color.black.opacity(0.92)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(FVColor.danger)
                            Text("Capture d'écran détectée")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Le coffre a été verrouillé.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            appLock.configureFromSettings()
            if authManager.phase == .vault {
                appLock.activateForVaultEntry()
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            appLock.handleScenePhase(newValue, userAuthenticated: authManager.phase == .vault)
        }
        .onChange(of: authManager.phase) { _, phase in
            if phase == .vault {
                appLock.activateForVaultEntry()
            } else {
                appLock.forceUnlock()
            }
        }
        .onChange(of: authManager.panicTriggered) { _, triggered in
            guard triggered else { return }
            vaultStore.wipeVaultForPanicMode()
            authManager.logout()
            authManager.clearPanicFlag()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fyxxVaultBiometricLimitReached)) { _ in
            vaultStore.wipeVaultForPanicMode()
            authManager.logout()
            appLock.forceUnlock()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fyxxVaultScreenshotDetected)) { _ in
            // Screenshot notifications are emitted after capture on iOS.
            // We immediately terminate the authenticated session to prevent continued exposure.
            authManager.logout()
            appLock.forceUnlock()
        }
        // Recovery key sheet (shown once, immediately after registration)
        .sheet(item: Binding(
            get: { authManager.pendingRecoveryKey.map { RecoveryKeyWrapper(key: $0) } },
            set: { if $0 == nil { authManager.dismissRecoveryKey() } }
        )) { wrapper in
            RecoveryKeyView(recoveryKey: wrapper.key) {
                authManager.dismissRecoveryKey()
            }
        }
    }
}

struct RecoveryKeyWrapper: Identifiable {
    let id = UUID()
    let key: String
}

// MARK: - Vault Lock View

struct VaultLockView: View {
    @ObservedObject var appLock: AppLockManager
    @ObservedObject var authManager: AuthManager
    @State private var masterPassword = ""
    @State private var masterUnlockError = ""
    @State private var showRecoveryKeyEntry = false
    @State private var recoveryKeyInput = ""
    @State private var recoveryKeyError = ""

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            FVBrandHeader(subtitle: "Coffre verrouillé")
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(FVColor.silver)

                if !appLock.lockError.isEmpty {
                    Text(appLock.lockError)
                        .foregroundStyle(FVColor.danger.opacity(0.9))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }

                FVButton(title: "Déverrouiller avec Face ID / Touch ID") {
                    Task { _ = await appLock.unlockWithBiometrics() }
                }

                FVTextField(title: "Mot de passe maître", text: $masterPassword, secure: true)
                if !masterUnlockError.isEmpty {
                    Text(masterUnlockError)
                        .foregroundStyle(FVColor.danger.opacity(0.9))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                FVButton(title: "Déverrouiller avec mot de passe") {
                    if authManager.verifyMasterPasswordForVaultUnlock(masterPassword) {
                        appLock.forceUnlock()
                        masterPassword = ""
                        masterUnlockError = ""
                    } else {
                        masterUnlockError = "Mot de passe maître incorrect."
                    }
                }

                if showRecoveryKeyEntry {
                    FVTextField(title: "Clé de récupération (XXXX-XXXX-...)", text: $recoveryKeyInput)
                    if !recoveryKeyError.isEmpty {
                        Text(recoveryKeyError).foregroundStyle(FVColor.danger.opacity(0.9))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    FVButton(title: "Déverrouiller avec clé de récupération") {
                        if authManager.unlockWithRecoveryKey(recoveryKeyInput) {
                            appLock.forceUnlock()
                            recoveryKeyInput = ""
                            recoveryKeyError = ""
                        } else {
                            recoveryKeyError = "Clé de récupération invalide."
                        }
                    }
                }

                Button(showRecoveryKeyEntry ? "Annuler la récupération" : "Utiliser la clé de récupération") {
                    showRecoveryKeyEntry.toggle()
                    recoveryKeyError = ""
                }
                .foregroundStyle(FVColor.violet.opacity(0.9))
                .font(.system(size: 13, weight: .medium, design: .rounded))

                Button("Retour à la connexion") { authManager.logout(); appLock.forceUnlock() }
                    .foregroundStyle(FVColor.silver.opacity(0.84))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .fvGlass()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20).padding(.vertical, 28)
    }
}

// MARK: - Auth View

struct AuthView: View {
    @ObservedObject var authManager: AuthManager
    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var panicPassword = ""
    @State private var showRecoveryEntry = false
    @State private var recoveryKeyInput = ""
    @State private var recoveryError = ""

    enum AuthMode: String, CaseIterable, Identifiable {
        case login = "Connexion"
        case register = "Inscription"
        var id: String { rawValue }
    }

    var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Exigences du mot de passe maître:")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
            requirements
        }
        .padding(10)
        .background(FVColor.abyss.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder var requirements: some View {
        FVRequirementRow(label: "12 caractères minimum", met: password.count >= 12)
        FVRequirementRow(label: "1 majuscule", met: password.rangeOfCharacter(from: .uppercaseLetters) != nil)
        FVRequirementRow(label: "1 chiffre", met: password.rangeOfCharacter(from: .decimalDigits) != nil)
        FVRequirementRow(label: "1 caractère spécial (!@#$...)", met: password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:,.<>?/\\\"'`~")) != nil)
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            FVBrandHeader(subtitle: "Accès sécurisé à ton coffre")

            HStack(spacing: 8) {
                FVTag(text: "AES-256", color: FVColor.cyan)
                FVTag(text: "MFA", color: FVColor.violet)
                FVTag(text: "Local", color: FVColor.success)
            }

            VStack(spacing: 16) {
                Picker("Mode", selection: $mode) {
                    ForEach(AuthMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)

                FVTextField(title: "Email", text: $email, keyboard: .email, contentType: .email)
                FVTextField(title: "Mot de passe maître", text: $password, secure: true, contentType: .password)

                if mode == .register {
                    if !password.isEmpty { passwordRequirements }
                    FVTextField(title: "Confirmer le mot de passe", text: $confirmPassword, secure: true, contentType: .password)
                    FVTextField(title: "Mot de passe panic (optionnel)", text: $panicPassword, secure: true)
                    Text("Le mot de passe panic efface immédiatement tout le coffre si utilisé à la place du mot de passe maître.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !authManager.authError.isEmpty {
                    Text(authManager.authError)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(FVColor.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                FVButton(title: mode == .login ? "Se connecter" : "Créer le compte") {
                    if mode == .login {
                        authManager.login(email: email, password: password)
                    } else {
                        authManager.register(email: email, password: password, confirmPassword: confirmPassword, panicPassword: panicPassword)
                    }
                }

                if mode == .login {
                    Button(showRecoveryEntry ? "Annuler" : "Mot de passe oublié? Utiliser la clé de récupération") {
                        showRecoveryEntry.toggle()
                        recoveryError = ""
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.violet.opacity(0.9))

                    if showRecoveryEntry {
                        FVTextField(title: "Clé de récupération (XXXX-XXXX-...)", text: $recoveryKeyInput)
                        if !recoveryError.isEmpty {
                            Text(recoveryError).foregroundStyle(FVColor.danger).font(.system(size: 12))
                        }
                        FVButton(title: "Accéder avec la clé de récupération") {
                            if authManager.unlockWithRecoveryKey(recoveryKeyInput) {
                                recoveryKeyInput = ""
                                recoveryError = ""
                            } else {
                                recoveryError = "Clé de récupération invalide."
                            }
                        }
                    }
                }
            }
            .fvGlass()

            Text("Connexion locale, chiffrée, sans compromis.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))

            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.25), value: mode)
    }
}

// MARK: - Recovery Key View (shown once after registration)

struct RecoveryKeyView: View {
    let recoveryKey: String
    let onDismiss: () -> Void
    @State private var confirmed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    FVBrandLogo(size: 50)

                    Text("Clé de récupération")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Si vous oubliez votre mot de passe maître, cette clé est le SEUL moyen de récupérer votre compte. Elle ne sera plus affichée.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 8) {
                        Text(recoveryKey)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(FVColor.cyanLight)
                            .multilineTextAlignment(.center)
                            .padding(16)
                            .background(FVColor.abyss.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FVColor.cyan.opacity(0.5), lineWidth: 1))
                            .fvGlow(FVColor.cyan)

                        FVButton(title: "Copier la clé", icon: "doc.on.doc", style: .secondary) {
                            ClipboardService.copy(recoveryKey.replacingOccurrences(of: "-", with: ""))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notez-la sur papier dans un endroit sûr", systemImage: "pencil.and.list.clipboard")
                        Label("Ne la partagez jamais", systemImage: "person.slash")
                        Label("Ne la stockez pas dans un fichier non chiffré", systemImage: "doc.badge.ellipsis")
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fvGlass()

                    Toggle("J'ai sauvegardé ma clé de récupération", isOn: $confirmed)
                        .toggleStyle(.switch)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    FVButton(title: "Continuer") {
                        guard confirmed else { return }
                        onDismiss()
                    }
                    .opacity(confirmed ? 1 : 0.4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle("Clé de récupération")
            .fvInlineNavTitle()
            .background(FVAnimatedBackground())
        }
        .interactiveDismissDisabled(!confirmed)
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @ObservedObject var authManager: AuthManager
    @State private var page = 0

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            FVBrandHeader(subtitle: "Bienvenue dans ton coffre sécurisé")
            TabView(selection: $page) {
                FVOnboardingFeature(
                    icon: "lock.doc.fill", title: "Coffre Chiffré",
                    description: "Tes identifiants sont stockés avec AES-GCM 256-bit et HMAC-SHA256.",
                    color: FVColor.cyan
                ).tag(0)

                FVOnboardingFeature(
                    icon: "checkmark.shield.fill", title: "MFA Par Compte",
                    description: "Ajoute une clé MFA (TOTP) pour chaque service.",
                    color: FVColor.violet
                ).tag(1)

                FVOnboardingFeature(
                    icon: "wand.and.stars", title: "Génération Intelligente",
                    description: "Crée des mots de passe robustes et vérifie leur sécurité.",
                    color: FVColor.gold
                ).tag(2)

                FVOnboardingFeature(
                    icon: "key.fill", title: "Clé de récupération",
                    description: "Tu as reçu une clé unique. Conserve-la précieusement.",
                    color: FVColor.success
                ).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 290)
            .fvGlass()

            HStack(spacing: 8) {
                ForEach(0..<4) { i in
                    Capsule()
                        .fill(i == page ? FVColor.cyan : Color.white.opacity(0.2))
                        .frame(width: i == page ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: page)
                }
            }

            FVButton(title: page < 3 ? "Continuer" : "Entrer dans le coffre") {
                if page < 3 {
                    withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                } else {
                    authManager.completeOnboarding()
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Vault Dashboard

enum VaultQuickAction {
    case weakPasswords
    case reusedPasswords
    case missingMFA
    case expiredPasswords
}

struct VaultDashboardView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var vaultStore: VaultStore

    @State private var selectedTab: Int = 1
    @State private var pendingQuickAction: VaultQuickAction?

    var body: some View {
        ZStack {
            Group {
                switch selectedTab {
                case 0:
                    SecurityDashboardView(vaultStore: vaultStore) { action in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedTab = 1
                        }
                        pendingQuickAction = action
                    }
                        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                case 1:
                    VaultListView(vaultStore: vaultStore, quickAction: $pendingQuickAction)
                        .transition(.opacity)
                case 2:
                    VaultSettingsView(authManager: authManager, vaultStore: vaultStore)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                default:
                    EmptyView()
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FVTabBar(selectedTab: $selectedTab)
        }
        .background(FVAnimatedBackground())
        .tint(FVColor.cyan)
    }
}

struct SecurityDashboardView: View {
    @ObservedObject var vaultStore: VaultStore
    var onRecommendationTap: (VaultQuickAction) -> Void
    @State private var editingEntry: VaultEntry?

    private var expiringEntries: [VaultEntry] {
        vaultStore.entries
            .filter { $0.isExpired || $0.isExpiringSoon }
            .sorted { ($0.daysUntilExpiration ?? .max) < ($1.daysUntilExpiration ?? .max) }
    }

    var body: some View {
        ScrollView {
            let audit = vaultStore.securityAudit
            let recommendations = actionableRecommendations(audit)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sécurité")
                        .font(FVFont.display(28))
                        .foregroundStyle(.white)
                    Text("ANALYSE EN TEMPS RÉEL")
                        .font(FVFont.caption(11))
                        .kerning(1.5)
                        .foregroundStyle(FVColor.smoke)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    FVSecurityGauge(score: audit.score, size: 160)
                    Text("Score de sécurité global")
                        .font(FVFont.caption(12))
                        .foregroundStyle(FVColor.mist.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .fvGlass()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    FVStatPill(icon: "exclamationmark.triangle", title: "À renforcer", value: "\(audit.weakCount)", color: FVColor.danger)
                    FVStatPill(icon: "arrow.triangle.2.circlepath", title: "Réutilisés", value: "\(audit.reusedCount)", color: FVColor.warning)
                    FVStatPill(icon: "shield.slash", title: "Sans MFA", value: "\(audit.withoutMFACount)", color: FVColor.violet)
                    FVStatPill(icon: "clock.badge.exclamationmark", title: "Expirés", value: "\(audit.expiredCount)", color: FVColor.rose)
                }

                VStack(alignment: .leading, spacing: 10) {
                    FVSectionHeader(icon: "lightbulb", title: "RECOMMANDATIONS")
                    ForEach(Array(recommendations.enumerated()), id: \.offset) { _, item in
                        Button {
                            guard let action = item.action else { return }
                            fvHaptic(.light)
                            onRecommendationTap(action)
                        } label: {
                            HStack(spacing: 10) {
                                Text(item.text)
                                    .font(FVFont.body(13))
                                    .foregroundStyle(.white.opacity(0.86))
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                Image(systemName: item.action == nil ? "checkmark.circle.fill" : "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(item.action == nil ? FVColor.success : FVColor.cyan.opacity(0.85))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(item.action == nil)
                    }
                }
                .fvGlass()

                VStack(alignment: .leading, spacing: 10) {
                    FVSectionHeader(icon: "clock.arrow.circlepath", title: "EXPIRATIONS")
                    if expiringEntries.isEmpty {
                        Text("Aucun mot de passe expiré actuellement.")
                            .font(FVFont.body(13))
                            .foregroundStyle(FVColor.mist.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(expiringEntries.prefix(6), id: \.id) { entry in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                        .font(FVFont.title(15))
                                        .foregroundStyle(.white)
                                    if let days = entry.daysUntilExpiration {
                                        Text(days < 0 ? "Expiré depuis \(abs(days)) jour(s)" : "Expire dans \(days) jour(s)")
                                            .font(FVFont.caption(11))
                                            .foregroundStyle(days < 0 ? FVColor.danger : FVColor.warning)
                                    }
                                }
                                Spacer(minLength: 10)
                                Button("Changer") { editingEntry = entry }
                                    .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
                            }
                        }
                    }
                }
                .fvGlass()

                VStack(alignment: .leading, spacing: 10) {
                    FVSectionHeader(icon: "checkmark.shield", title: "ALERTES BREACH")
                    if audit.reusedCount > 0 {
                        Text("Des réutilisations sont détectées. Vérifie les mots de passe compromis dans l'édition de compte.")
                            .font(FVFont.body(13))
                            .foregroundStyle(FVColor.warning)
                    } else {
                        Label("Aucune fuite détectée", systemImage: "checkmark.circle.fill")
                            .font(FVFont.body(13))
                            .foregroundStyle(FVColor.success)
                    }
                }
                .fvGlass()

                Color.clear.frame(height: 120)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $editingEntry) { entry in
            EditVaultEntryView(vaultStore: vaultStore, entry: entry)
        }
    }

    private struct SecurityRecommendation {
        let text: String
        let action: VaultQuickAction?
    }

    private func actionableRecommendations(_ audit: SecurityAudit) -> [SecurityRecommendation] {
        var items: [SecurityRecommendation] = []
        if audit.weakCount > 0 {
            items.append(.init(text: "Renforce \(audit.weakCount) mot(s) de passe à améliorer.", action: .weakPasswords))
        }
        if audit.reusedCount > 0 {
            items.append(.init(text: "Évite la réutilisation (\(audit.reusedCount) entrée(s)).", action: .reusedPasswords))
        }
        if audit.withoutMFACount > 0 {
            items.append(.init(text: "Active le MFA sur \(audit.withoutMFACount) compte(s).", action: .missingMFA))
        }
        if audit.expiredCount > 0 {
            items.append(.init(text: "\(audit.expiredCount) mot(s) de passe expiré(s) à renouveler.", action: .expiredPasswords))
        }
        if items.isEmpty {
            items.append(.init(text: "Excellent niveau de sécurité.", action: nil))
        }
        return items
    }
}

struct VaultListView: View {
    @ObservedObject var vaultStore: VaultStore
    @Binding var quickAction: VaultQuickAction?

    @State private var showAddSheet = false
    @State private var query = ""
    @State private var pendingDeleteEntry: VaultEntry?
    @State private var editingEntry: VaultEntry?
    @State private var lastDeletedTrashID: UUID?
    @State private var showUndoDeleteToast = false
    @State private var selectionMode = false
    @State private var selectedEntryIDs: Set<UUID> = []
    @State private var showBulkDeleteConfirm = false
    @State private var showBulkTagPrompt = false
    @State private var showBulkFolderPrompt = false
    @State private var bulkTagText = ""
    @State private var bulkFolderText = ""
    @State private var sortMode: VaultSortMode = .recent
    @State private var filterMode: VaultFilterMode = .all
    @AppStorage("fyxxvault.compact.cards") private var compactCards = false
    @AppStorage("fyxxvault.accent.mode") private var accentMode = 0

    private var filteredEntries: [VaultEntry] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var source = vaultStore.entries
        switch filterMode {
        case .all: break
        case .favorites: source = source.filter { $0.isFavorite }
        case .weak: source = source.filter { [.faible, .moyen].contains(PasswordToolkit.strength(for: $0.password)) }
        case .mfa: source = source.filter { $0.mfaEnabled }
        case .expired: source = source.filter { $0.isExpired || $0.isExpiringSoon }
        }
        let queried = cleanQuery.isEmpty ? source : source.filter {
            $0.title.localizedCaseInsensitiveContains(cleanQuery)
            || $0.username.localizedCaseInsensitiveContains(cleanQuery)
            || $0.website.localizedCaseInsensitiveContains(cleanQuery)
        }
        switch sortMode {
        case .recent:        return queried.sorted { $0.lastModifiedAt > $1.lastModifiedAt }
        case .alphabetical:  return queried.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .strength:
            let w: (PasswordStrength) -> Int = { switch $0 { case .faible: 0; case .moyen: 1; case .fort: 2; case .excellent: 3 } }
            return queried.sorted { w(PasswordToolkit.strength(for: $0.password)) < w(PasswordToolkit.strength(for: $1.password)) }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Coffre")
                                .font(FVFont.display(32))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            Text("Stockage chiffré local • accès MFA par entrée")
                                .font(FVFont.caption(11))
                                .kerning(0.8)
                                .foregroundStyle(FVColor.mist.opacity(0.78))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }

                        Spacer(minLength: 8)

                        VStack(spacing: 2) {
                            Text("\(vaultStore.entries.count)")
                                .font(FVFont.display(28))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                            Text("COMPTES")
                                .font(FVFont.caption(10))
                                .kerning(1.8)
                                .foregroundStyle(FVColor.mist.opacity(0.86))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.2), FVColor.violet.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }

                    if !vaultStore.persistenceError.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(FVColor.danger)
                            Text(vaultStore.persistenceError)
                                .font(FVFont.caption(12))
                                .foregroundStyle(FVColor.danger)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fvGlass()
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(FVColor.mist.opacity(0.75))
                        TextField("Recherche", text: $query).fvPlatformTextEntry().foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.14), FVColor.violet.opacity(0.28)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    )
                    .fvGlass(cornerRadius: 18, padding: 0)

                    HStack(spacing: 10) {
                        Menu {
                            ForEach(VaultFilterMode.allCases) { f in
                                Button(f.rawValue) { filterMode = f }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "line.3.horizontal.decrease")
                                Text(filterMode.rawValue)
                            }
                            .font(FVFont.caption(12))
                            .foregroundStyle(FVColor.cyan)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(FVColor.cyan.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(FVColor.cyan.opacity(0.15)))
                        }

                        Menu {
                            ForEach(VaultSortMode.allCases) { m in
                                Button(m.rawValue) { sortMode = m }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.arrow.down")
                                Text(sortMode.rawValue)
                            }
                            .font(FVFont.caption(12))
                            .foregroundStyle(FVColor.cyan)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(FVColor.cyan.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(FVColor.cyan.opacity(0.15)))
                        }
                        Spacer()
                        Button(selectionMode ? "Terminer" : "Sélectionner") {
                            selectionMode.toggle()
                            if !selectionMode { selectedEntryIDs.removeAll() }
                        }
                        .font(FVFont.caption(11))
                        .foregroundStyle(FVColor.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(FVColor.cyan.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(FVColor.cyan.opacity(0.15)))
                    }
                    .fvGlass(cornerRadius: 14, padding: 12)

                    if selectionMode {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                Text("\(selectedEntryIDs.count) sélectionné(s)")
                                    .font(FVFont.caption(11))
                                    .kerning(1.2)
                                    .foregroundStyle(FVColor.mist.opacity(0.9))
                                Button("Taguer") { showBulkTagPrompt = true }.font(FVFont.caption(12)).foregroundStyle(FVColor.cyan)
                                Button("Déplacer") { showBulkFolderPrompt = true }.font(FVFont.caption(12)).foregroundStyle(FVColor.cyan)
                                Button("Favori") { vaultStore.bulkSetFavorite(entryIDs: selectedEntryIDs, value: true) }.font(FVFont.caption(12)).foregroundStyle(.yellow.opacity(0.9))
                                Button("Supprimer") { showBulkDeleteConfirm = true }.font(FVFont.caption(12)).foregroundStyle(FVColor.danger.opacity(0.9))
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fvGlass(cornerRadius: 14, padding: 12)
                    }

                    if !vaultStore.integrityWarning.isEmpty {
                        Text(vaultStore.integrityWarning)
                            .font(FVFont.caption(12))
                            .foregroundStyle(FVColor.danger.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fvGlass()
                    }

                    if filteredEntries.isEmpty {
                        FVEmptyState(icon: "lock.rectangle.stack", title: "Aucun mot de passe", subtitle: "Ajoute ton premier compte sécurisé")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                                VaultEntryCard(
                                    entry: entry,
                                    onDelete: { pendingDeleteEntry = entry },
                                    onEdit: { editingEntry = entry },
                                    onCopyPassword: { vaultStore.markCopied("mot de passe", title: entry.title) },
                                    onCopyMFA: { vaultStore.markCopied("MFA", title: entry.title) },
                                    selectionMode: selectionMode,
                                    isSelected: selectedEntryIDs.contains(entry.id),
                                    onTapCard: {
                                        guard selectionMode else { return }
                                        if selectedEntryIDs.contains(entry.id) { selectedEntryIDs.remove(entry.id) }
                                        else { selectedEntryIDs.insert(entry.id) }
                                    },
                                    compact: compactCards,
                                    accentMode: accentMode
                                )
                                .fvAppear(delay: Double(index) * 0.05)
                            }
                        }
                    }

                    Color.clear.frame(height: 130)
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollIndicators(.hidden)

            if showUndoDeleteToast {
                HStack {
                    Text("Compte supprimé").font(FVFont.caption(13)).foregroundStyle(.white)
                    Spacer()
                    Button("Annuler") {
                        if let id = lastDeletedTrashID { vaultStore.restoreFromTrash(id) }
                        showUndoDeleteToast = false
                        lastDeletedTrashID = nil
                    }
                    .font(FVFont.caption(13))
                    .foregroundStyle(FVColor.cyan)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16).padding(.bottom, 96)
            }

            // FAB — Floating Action Button
            Button {
                fvHaptic(.medium)
                showAddSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(FVColor.cyan.opacity(0.15))
                        .frame(width: 68, height: 68)

                    Circle()
                        .fill(FVGradient.cyanToViolet)
                        .frame(width: 54, height: 54)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1.2))
                        .shadow(color: FVColor.cyan.opacity(0.4), radius: 14, y: 4)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 6)

                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 68)
        }
        .sheet(isPresented: $showAddSheet) { AddVaultEntryView(vaultStore: vaultStore) }
        .sheet(item: $editingEntry) { entry in EditVaultEntryView(vaultStore: vaultStore, entry: entry) }
        .confirmationDialog("Supprimer ce compte ?", isPresented: Binding(get: { pendingDeleteEntry != nil }, set: { if !$0 { pendingDeleteEntry = nil } }), titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) { if let e = pendingDeleteEntry { delete(entry: e) }; pendingDeleteEntry = nil }
            Button("Annuler", role: .cancel) { pendingDeleteEntry = nil }
        } message: { Text("Le compte sera déplacé dans la corbeille pendant 30 jours.") }
        .confirmationDialog("Supprimer la sélection ?", isPresented: $showBulkDeleteConfirm, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) { vaultStore.bulkMoveToTrash(entryIDs: selectedEntryIDs); selectedEntryIDs.removeAll(); selectionMode = false }
            Button("Annuler", role: .cancel) {}
        } message: { Text("Les comptes sélectionnés iront dans la corbeille.") }
        .alert("Ajouter un tag", isPresented: $showBulkTagPrompt) {
            TextField("Tag", text: $bulkTagText)
            Button("Appliquer") { vaultStore.bulkApplyTag(entryIDs: selectedEntryIDs, tag: bulkTagText); bulkTagText = "" }
            Button("Annuler", role: .cancel) { bulkTagText = "" }
        }
        .alert("Déplacer vers dossier", isPresented: $showBulkFolderPrompt) {
            TextField("Nom du dossier", text: $bulkFolderText)
            Button("Déplacer") { vaultStore.bulkMoveToFolder(entryIDs: selectedEntryIDs, folder: bulkFolderText); bulkFolderText = "" }
            Button("Annuler", role: .cancel) { bulkFolderText = "" }
        }
        .onAppear {
            if let action = quickAction {
                applyQuickAction(action)
                quickAction = nil
            }
        }
        .onChange(of: quickAction) { _, newValue in
            guard let action = newValue else { return }
            applyQuickAction(action)
            quickAction = nil
        }
    }

    private func delete(entry: VaultEntry) {
        lastDeletedTrashID = vaultStore.moveToTrash(entryID: entry.id)
        showUndoDeleteToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            showUndoDeleteToast = false
            lastDeletedTrashID = nil
        }
    }

    private func applyQuickAction(_ action: VaultQuickAction) {
        query = ""
        selectionMode = false
        selectedEntryIDs.removeAll()

        switch action {
        case .weakPasswords:
            filterMode = .weak
            sortMode = .strength
            editingEntry = vaultStore.entries.first {
                [.faible, .moyen].contains(PasswordToolkit.strength(for: $0.password))
            }
        case .expiredPasswords:
            filterMode = .expired
            sortMode = .recent
            editingEntry = vaultStore.entries
                .filter { $0.isExpired || $0.isExpiringSoon }
                .sorted { ($0.daysUntilExpiration ?? .max) < ($1.daysUntilExpiration ?? .max) }
                .first
        case .missingMFA:
            filterMode = .all
            sortMode = .recent
            editingEntry = vaultStore.entries.first { !$0.mfaEnabled }
        case .reusedPasswords:
            filterMode = .all
            sortMode = .recent
            editingEntry = firstDuplicatedPasswordEntry()
        }
    }

    private func firstDuplicatedPasswordEntry() -> VaultEntry? {
        var counts: [String: Int] = [:]
        for entry in vaultStore.entries where !entry.password.isEmpty {
            counts[entry.password, default: 0] += 1
        }
        let duplicated = Set(counts.filter { $0.value > 1 }.map(\.key))
        return vaultStore.entries.first { duplicated.contains($0.password) }
    }
}

// MARK: - Vault Settings

struct VaultSettingsView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var vaultStore: VaultStore

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
            // CSV Export Warning
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

struct LogoutConfirmSheet: View {
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        ZStack {
            FVAnimatedBackground()
            VStack(spacing: 16) {
                Circle()
                    .fill(FVGradient.violetToRose)
                    .frame(width: 62, height: 62)
                    .overlay(
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    )

                Text("Confirmer la déconnexion")
                    .font(FVFont.heading(24))
                    .foregroundStyle(.white)

                Text("Tu devras te reconnecter avec ton email et ton mot de passe maître.")
                    .font(FVFont.body(14))
                    .foregroundStyle(FVColor.mist)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                HStack(spacing: 10) {
                    Button("Annuler", action: onCancel)
                        .buttonStyle(FVSettingsButton(tint: FVColor.silver.opacity(0.45)))
                    Button("Se déconnecter", action: onConfirm)
                        .buttonStyle(FVSettingsButton(tint: FVColor.danger.opacity(0.92)))
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authManager: AuthManager

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var success = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "key.rotation")
                        .font(.system(size: 40))
                        .foregroundStyle(FVColor.cyan)
                        .padding(.top, 10)

                    Text("Changer le mot de passe maître")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if success {
                        Label("Mot de passe changé avec succès.", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(FVColor.cyan)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fvGlass()
                    } else {
                        VStack(spacing: 12) {
                            FVTextField(title: "Mot de passe actuel", text: $currentPassword, secure: true)
                            FVTextField(title: "Nouveau mot de passe", text: $newPassword, secure: true)

                            if !newPassword.isEmpty {
                                passwordRequirements
                            }

                            FVTextField(title: "Confirmer le nouveau mot de passe", text: $confirmPassword, secure: true)

                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(FVColor.danger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            FVButton(title: "Changer le mot de passe") {
                                if let error = authManager.changeMasterPassword(
                                    currentPassword: currentPassword,
                                    newPassword: newPassword,
                                    confirmPassword: confirmPassword
                                ) {
                                    errorMessage = error
                                } else {
                                    success = true
                                    currentPassword = ""
                                    newPassword = ""
                                    confirmPassword = ""
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { dismiss() }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
            .navigationTitle("Changer le mot de passe")
            .fvInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundStyle(FVColor.cyan)
                }
            }
            .background(FVAnimatedBackground())
        }
    }

    var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: 4) {
            FVRequirementRow(label: "12 caractères minimum", met: newPassword.count >= 12)
            FVRequirementRow(label: "1 majuscule", met: newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil)
            FVRequirementRow(label: "1 chiffre", met: newPassword.rangeOfCharacter(from: .decimalDigits) != nil)
            FVRequirementRow(label: "1 caractère spécial", met: newPassword.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:,.<>?/\\\"'`~")) != nil)
        }
        .padding(10)
        .background(FVColor.abyss.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Vault Entry Card

struct VaultEntryCard: View {
    let entry: VaultEntry
    var onDelete: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onCopyPassword: (() -> Void)? = nil
    var onCopyMFA: (() -> Void)? = nil
    var selectionMode: Bool = false
    var isSelected: Bool = false
    var onTapCard: (() -> Void)? = nil
    var compact: Bool = false
    var accentMode: Int = 0
    @State private var revealPassword = false
    @State private var didCopyPassword = false
    @State private var showMFACode = true
    @AppStorage("fyxxvault.hide.passwords.default") private var hidePasswordsByDefault = true
    @AppStorage("fyxxvault.hide.mfa.default") private var hideMFACodeByDefault = false
    @AppStorage("fyxxvault.haptics.enabled") private var hapticsEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 10) {
            HStack {
                HStack(spacing: 10) {
                    Circle()
                        .fill(
                            LinearGradient(colors: [FVColor.cyan.opacity(0.9), FVColor.violet.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 34, height: 34)
                        .overlay {
                            Text(String(entry.title.prefix(1)).uppercased())
                                .font(FVFont.label(14))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.title).font(FVFont.title(compact ? 16 : 18)).foregroundStyle(.white)
                        if entry.isFavorite { Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(.yellow.opacity(0.9)) }
                        // Expiration indicators
                        if entry.isExpired {
                            Label("Expiré", systemImage: "clock.badge.exclamationmark.fill")
                                .font(.system(size: 10, weight: .bold)).foregroundStyle(FVColor.danger)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.red.opacity(0.15)).clipShape(Capsule())
                        } else if entry.isExpiringSoon {
                            Label("Expire bientôt", systemImage: "clock.fill")
                                .font(.system(size: 10, weight: .bold)).foregroundStyle(.orange)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.orange.opacity(0.15)).clipShape(Capsule())
                        }
                    }
                    if !entry.website.isEmpty {
                        Text(entry.website)
                            .font(FVFont.caption(compact ? 11 : 12))
                            .foregroundStyle(FVColor.cyan)
                            .lineLimit(1)
                    }
                }
                }
                Spacer()
                if let onEdit {
                    Button { onEdit() } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                if let onDelete {
                    Button { onDelete() } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FVColor.danger.opacity(0.9))
                            .frame(width: 28, height: 28)
                            .background(FVColor.danger.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
            }

            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)

            Text(entry.username).font(FVFont.body(14)).foregroundStyle(.white.opacity(0.8))

            HStack(spacing: 8) {
                Text(revealPassword ? entry.password : String(repeating: "•", count: max(entry.password.count, 8)))
                    .font(.custom("Menlo", size: 13)).foregroundStyle(.white.opacity(0.95)).lineLimit(1)
                    .privacySensitive()
                Spacer()
                Button {
                    ClipboardService.copy(entry.password); onCopyPassword?()
                    fvHaptic(.light)
                    didCopyPassword = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { didCopyPassword = false }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: didCopyPassword ? "checkmark.circle.fill" : "doc.on.doc")
                        Text(didCopyPassword ? "Copié" : "Copier")
                    }
                    .font(FVFont.caption(11))
                    .foregroundStyle(didCopyPassword ? FVColor.cyan : FVColor.silver)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                }
                Button(revealPassword ? "Masquer" : "Afficher") { revealPassword.toggle() }
                    .font(FVFont.caption(11))
                    .foregroundStyle(FVColor.silver)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            }

            if entry.expirationPolicy != .none, let days = entry.daysUntilExpiration {
                Text(days < 0 ? "Mot de passe expiré depuis \(abs(days)) jour(s)" : "Expire dans \(days) jour(s) (\(entry.expirationPolicy.label))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(days < 0 ? .red : (days < 14 ? .orange : .white.opacity(0.55)))
            }

            if !entry.notes.isEmpty { Text(entry.notes).font(FVFont.body(13)).foregroundStyle(.white.opacity(0.67)) }

            if entry.mfaEnabled && entry.mfaType == .totp {
                Button(showMFACode ? "Masquer le code 2FA" : "Afficher le code 2FA") { showMFACode.toggle(); fvHaptic(.light) }
                    .font(FVFont.body(12)).foregroundStyle(FVColor.cyan)
                if showMFACode { TOTPCodePanel(secretInput: entry.mfaSecret, accentMode: accentMode, onCopy: onCopyMFA) }
            }
        }
        .fvGlass()
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(isSelected ? FVColor.cyan : .clear, lineWidth: 2))
        .overlay(alignment: .topTrailing) {
            if selectionMode { Image(systemName: isSelected ? "checkmark.circle.fill" : "circle").foregroundStyle(isSelected ? FVColor.cyan : .white.opacity(0.5)).padding(10) }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTapCard?() }
        .onAppear { revealPassword = !hidePasswordsByDefault; showMFACode = !hideMFACodeByDefault }
    }
}

// MARK: - TOTP Code Panel

struct TOTPCodePanel: View {
    let secretInput: String
    var accentMode: Int = 0
    var onCopy: (() -> Void)? = nil
    @State private var didCopyCode = false
    @AppStorage("fyxxvault.haptics.enabled") private var hapticsEnabled = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = TOTPService.snapshot(secretInput: secretInput, at: timeline.date)
            VStack(alignment: .leading, spacing: 8) {
                Text("Code 2FA").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.68))
                if let snapshot {
                    HStack {
                        Text(formatted(snapshot.code))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(FVColor.cyan)
                            .privacySensitive()
                        Button {
                            ClipboardService.copy(snapshot.code); onCopy?()
                            fvHaptic(.light)
                            didCopyCode = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { didCopyCode = false }
                        } label: { Image(systemName: didCopyCode ? "checkmark.circle.fill" : "doc.on.doc") }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(didCopyCode ? FVColor.cyan : .white.opacity(0.82))
                        Spacer()
                        Text("\(snapshot.remainingSeconds)s").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.78))
                    }
                    GeometryReader { geo in
                        let progress = Double(snapshot.remainingSeconds) / 30.0
                        Capsule().fill(Color.white.opacity(0.14))
                            .overlay(alignment: .leading) { Capsule().fill(FVColor.cyan).frame(width: geo.size.width * progress) }
                    }
                    .frame(height: 6)
                } else {
                    Text("Clé TOTP invalide").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(FVColor.danger.opacity(0.9))
                }
            }
            .padding(10).background(Color.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func formatted(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }
}

// MARK: - Password Strength View

struct PasswordStrengthView: View {
    let password: String
    var strength: PasswordStrength { PasswordToolkit.strength(for: password) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Robustesse").font(FVFont.body(13)).foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 10) {
                Capsule().fill(strength.color).frame(width: 66, height: 10)
                Text(strength.rawValue).font(FVFont.body(14)).foregroundStyle(strength.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).fvGlass()
    }
}

// MARK: - Password Generator View

struct PasswordGeneratorView: View {
    @Binding var policy: PasswordPolicy
    var onGenerate: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Générateur").font(FVFont.body(16)).foregroundStyle(.white)
            Picker("Mode", selection: $policy.mode) {
                ForEach(PasswordGenerationMode.allCases) { m in Text(m.rawValue).tag(m) }
            }.pickerStyle(.segmented)
            if policy.mode == .random {
                Text("Longueur: \(policy.length)").font(FVFont.body(13)).foregroundStyle(.white.opacity(0.8))
                Slider(value: Binding(get: { Double(policy.length) }, set: { policy.length = Int($0) }), in: 8...40, step: 1).tint(FVColor.cyan)
                Toggle("Majuscules", isOn: $policy.includeUppercase)
                Toggle("Minuscules", isOn: $policy.includeLowercase)
                Toggle("Chiffres", isOn: $policy.includeNumbers)
                Toggle("Caractères spéciaux", isOn: $policy.includeSymbols)
            } else {
                Stepper("Nombre de mots: \(policy.wordsCount)", value: $policy.wordsCount, in: 3...8).foregroundStyle(.white.opacity(0.85))
            }
            FVButton(title: "Générer") { onGenerate() }
        }
        .toggleStyle(.switch).fvGlass()
    }
}

// MARK: - Add Vault Entry

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
                    FVTextField(title: "Nom du compte", text: $title)
                    FVTextField(title: "Site web", text: $website)
                    FVTextField(title: "Identifiant / Email", text: $username)
                    FVTextField(title: "Mot de passe", text: $password)
                    PasswordStrengthView(password: password)
                    PasswordGeneratorView(policy: $policy) { password = PasswordToolkit.generate(policy: policy) }
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
                        guard !cleanTitle.isEmpty, !password.isEmpty, !isDuplicateEntry else { return }
                        guard !mfaEnabled || !mfaSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        vaultStore.addEntry(VaultEntry(
                            title: cleanTitle,
                            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password,
                            website: website.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            mfaEnabled: mfaEnabled,
                            mfaType: mfaEnabled ? .totp : nil,
                            mfaSecret: mfaEnabled ? mfaSecret.trimmingCharacters(in: .whitespacesAndNewlines) : "",
                            isFavorite: isFavorite,
                            customFields: customFields,
                            expirationPolicy: expirationPolicy
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

// MARK: - Edit Vault Entry

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

// MARK: - Trash / Activity / Reorder

struct VaultReorderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vaultStore: VaultStore
    var body: some View {
        NavigationStack {
            List {
                ForEach(vaultStore.entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title).font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text(entry.username).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    }
                }
                .onMove(perform: vaultStore.reorderEntries)
            }
            .navigationTitle("Réorganiser")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { EditButton() }
            }
        }
    }
}

struct VaultTrashView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vaultStore: VaultStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if vaultStore.trashEntries.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "trash.slash").font(.system(size: 36)).foregroundStyle(.white.opacity(0.7))
                            Text("Corbeille vide").font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 48).fvGlass()
                    } else {
                        ForEach(vaultStore.trashEntries.sorted(by: { $0.deletedAt > $1.deletedAt })) { trash in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(trash.entry.title).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                Text(trash.entry.username).foregroundStyle(.white.opacity(0.72))
                                Text("Suppression dans \(max(0, Calendar.current.dateComponents([.day], from: Date(), to: trash.expiresAt).day ?? 0)) jour(s)")
                                    .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.58))
                                HStack {
                                    Button("Restaurer") { vaultStore.restoreFromTrash(trash.id) }.foregroundStyle(FVColor.cyan)
                                    Spacer()
                                    Button("Supprimer définitivement", role: .destructive) { vaultStore.permanentlyDeleteFromTrash(trash.id) }
                                }
                            }.fvGlass()
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 22)
            }
            .navigationTitle("Corbeille").fvInlineNavTitle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() }.foregroundStyle(FVColor.cyan) } }
            .background(FVAnimatedBackground())
        }
    }
}

struct ActivityLogView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vaultStore: VaultStore
    @State private var showExporter = false
    @State private var logDocument: TextFileDocument?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    if vaultStore.activityLog.isEmpty {
                        Text("Aucune activité").foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity).padding(.vertical, 40).fvGlass()
                    } else {
                        ForEach(vaultStore.activityLog.prefix(500)) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.action).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                                    Text(item.target).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.72))
                                }
                                Spacer()
                                Text(item.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.56))
                            }.fvGlass()
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 22)
            }
            .navigationTitle("Journal (\(vaultStore.activityLog.count))").fvInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() }.foregroundStyle(FVColor.cyan) }
                ToolbarItem(placement: .primaryAction) {
                    Button("Exporter") {
                        logDocument = TextFileDocument(text: vaultStore.exportActivityLogText())
                        showExporter = true
                    }
                    .foregroundStyle(FVColor.cyan)
                }
            }
            .fileExporter(isPresented: $showExporter, document: logDocument, contentType: .plainText, defaultFilename: "FyxxVault-ActivityLog-\(Int(Date().timeIntervalSince1970))") { _ in }
            .background(FVAnimatedBackground())
        }
    }
}

// MARK: - QR Scanner

struct QRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onScanned: (String) -> Void
    @State private var scannedValue = ""

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            QRScannerRepresentable { value in scannedValue = value; onScanned(value); dismiss() }.ignoresSafeArea()
            #else
            FVAnimatedBackground()
            #endif
            LinearGradient(colors: [.black.opacity(0.72), .black.opacity(0.1), .black.opacity(0.72)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack { Button("Fermer") { dismiss() }.font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(FVColor.cyanLight); Spacer() }
                    .padding(.horizontal, 20).padding(.top, 6)
                VStack(spacing: 6) {
                    Text("Scanner le QR TOTP").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("Vise le QR dans le cadre, la détection est automatique.").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.82))
                }
                Spacer()
                RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(FVColor.cyanLight.opacity(0.9), lineWidth: 2).frame(width: 250, height: 250)
                Spacer()
            }
        }
    }
}

#if canImport(UIKit)
struct QRScannerRepresentable: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController(); vc.onCodeScanned = onCodeScanned; return vc
    }
    func updateUIViewController(_ vc: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasEmittedCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        session.sessionPreset = .high
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return }
        session.addInput(input)
        if camera.isFocusModeSupported(.continuousAutoFocus) {
            try? camera.lockForConfiguration()
            camera.focusMode = .continuousAutoFocus
            if camera.isExposureModeSupported(.continuousAutoExposure) { camera.exposureMode = .continuousAutoExposure }
            camera.unlockForConfiguration()
        }
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill; preview.frame = view.bounds
        view.layer.addSublayer(preview); previewLayer = preview
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasEmittedCode = false
        if !session.isRunning { DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() } }
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); previewLayer?.frame = view.bounds }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if session.isRunning { DispatchQueue.global(qos: .userInitiated).async { self.session.stopRunning() } }
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasEmittedCode, let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let code = obj.stringValue else { return }
        hasEmittedCode = true; session.stopRunning(); onCodeScanned?(code)
    }
}
#endif

// MARK: - File Documents

struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.fyxxVaultBackup] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let regular = configuration.file.regularFileContents else { throw BackupError.malformedData }
        data = regular
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct TextFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let t = String(data: data, encoding: .utf8) else { self.text = ""; return }
        text = t
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}

extension UTType {
    static let fyxxVaultBackup = UTType(exportedAs: "fyxx.backup")
}

#Preview {
    ContentView()
}
