import SwiftUI
import Foundation
import Combine

@MainActor
final class AuthManager: ObservableObject {
    @Published var phase: SessionPhase = .auth
    @Published var authError = ""
    @Published var panicTriggered = false
    /// Holds the raw (unhashed) recovery key immediately after registration, then nilled.
    @Published var pendingRecoveryKey: String? = nil

    /// Cloud sync service — wired up by ContentView via setSyncService(_:)
    private var syncService: SyncService?

    private var account: Account?
    /// In-memory mirror of the persisted attempt counter
    private var failedAttempts: Int = 0
    private var lockoutUntil: Date?

    init() {
        loadAccount()
        loadPersistedAttemptState()
    }

    // MARK: Sync Integration

    func setSyncService(_ service: SyncService) {
        self.syncService = service
    }

    // MARK: Registration

    func register(email: String, password: String, confirmPassword: String, panicPassword: String) {
        authError = ""

        // RFC 5322-inspired email validation
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard PasswordValidator.validateEmail(cleanEmail) else {
            authError = "Adresse email invalide."
            return
        }

        // Master password complexity
        let (pwValid, pwReason) = PasswordValidator.validateMasterPassword(password)
        guard pwValid else {
            authError = pwReason
            return
        }

        guard password == confirmPassword else {
            authError = "Les mots de passe ne correspondent pas."
            return
        }

        if !panicPassword.isEmpty {
            guard panicPassword.count >= 8 else {
                authError = "Le mot de passe panic doit contenir au moins 8 caractères."
                return
            }
            guard panicPassword != password else {
                authError = "Le mot de passe panic doit être différent du mot de passe maître."
                return
            }
        }

        // Hash master password
        let salt = CryptoService.makeSalt()
        let hash = CryptoService.hashMasterPasswordPBKDF2(password, salt: salt, rounds: CryptoService.masterRounds())

        // Hash panic password if provided
        let panicSalt = panicPassword.isEmpty ? nil : CryptoService.makeSalt()
        let panicHash = panicSalt.map {
            CryptoService.hashMasterPasswordPBKDF2(panicPassword, salt: $0, rounds: CryptoService.masterRounds())
        }

        // Generate recovery key
        let rawRecoveryKey = CryptoService.generateRecoveryKey()
        let recoverySalt = CryptoService.makeSalt()
        let recoveryHash = CryptoService.hashRecoveryKey(rawRecoveryKey, salt: recoverySalt)

        let created = Account(
            email: cleanEmail,
            passwordSalt: salt,
            passwordHash: hash,
            passwordHashAlgorithm: "pbkdf2-sha256",
            passwordHashRounds: CryptoService.masterRounds(),
            panicSalt: panicSalt,
            panicHash: panicHash,
            didCompleteOnboarding: false,
            recoveryKeyHash: recoveryHash,
            recoveryKeySalt: recoverySalt
        )

        account = created
        persistAccount()
        resetFailedAttempts()

        // Show recovery key to user ONCE
        pendingRecoveryKey = CryptoService.formatRecoveryKey(rawRecoveryKey)
        phase = .onboarding

        // Auto cloud sync: sign up in the background (failures are silent)
        if let syncService {
            let email = cleanEmail
            let pw = password
            Task {
                try? await syncService.signUpWithEmail(email: email, password: pw, masterPassword: pw)
            }
        }
    }

    // MARK: Login

    func login(email: String, password: String) {
        authError = ""

        // Check persistent lockout
        if let lockoutUntil, Date() < lockoutUntil {
            let remaining = Int(lockoutUntil.timeIntervalSinceNow.rounded(.up))
            authError = "Trop de tentatives. Réessaie dans \(max(remaining, 1))s."
            return
        }

        guard let account else {
            authError = "Aucun compte trouvé. Crée ton compte d'abord."
            return
        }

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleanEmail == account.email else {
            registerFailure()
            authError = "Email inconnu."
            return
        }

        // Panic password check (before master password, constant time comparison not needed here as panic wipes anyway)
        if let panicSalt = account.panicSalt, let panicHash = account.panicHash {
            let panicCandidate = CryptoService.hashMasterPasswordPBKDF2(
                password, salt: panicSalt, rounds: max(account.passwordHashRounds, CryptoService.masterRounds())
            )
            if panicCandidate == panicHash {
                panicTriggered = true
                authError = "Mode panic activé."
                phase = .auth
                return
            }
        }

        guard CryptoService.verifyMasterPassword(password, account: account) else {
            registerFailure()
            authError = "Mot de passe incorrect. (\(failedAttempts) tentative(s) échouée(s))"
            return
        }

        resetFailedAttempts()
        migrateAccountHashIfNeeded(password: password)
        phase = account.didCompleteOnboarding ? .vault : .onboarding

        // Auto cloud sync: sign in in the background (failures are silent)
        if let syncService {
            let email = cleanEmail
            let pw = password
            Task {
                try? await syncService.signInWithEmail(email: email, password: pw, masterPassword: pw)
            }
        }
    }

    // MARK: Recovery Key Unlock

    func unlockWithRecoveryKey(_ key: String) -> Bool {
        guard let account else { return false }
        let clean = key.replacingOccurrences(of: "-", with: "").uppercased()
        guard !clean.isEmpty else { return false }
        guard CryptoService.verifyRecoveryKey(clean, account: account) else { return false }
        resetFailedAttempts()
        phase = account.didCompleteOnboarding ? .vault : .onboarding
        return true
    }

    // MARK: Master Password Change

    /// Returns nil on success, error message on failure.
    func changeMasterPassword(currentPassword: String, newPassword: String, confirmPassword: String) -> String? {
        guard let acc = account else { return "Aucun compte trouvé." }

        guard CryptoService.verifyMasterPassword(currentPassword, account: acc) else {
            return "Mot de passe actuel incorrect."
        }

        let (valid, reason) = PasswordValidator.validateMasterPassword(newPassword)
        guard valid else { return reason }
        guard newPassword == confirmPassword else { return "Les mots de passe ne correspondent pas." }
        guard newPassword != currentPassword else { return "Le nouveau mot de passe doit être différent de l'actuel." }

        let salt = CryptoService.makeSalt()
        let hash = CryptoService.hashMasterPasswordPBKDF2(newPassword, salt: salt, rounds: CryptoService.masterRounds())

        var updated = acc
        updated.passwordSalt = salt
        updated.passwordHash = hash
        updated.passwordHashAlgorithm = "pbkdf2-sha256"
        updated.passwordHashRounds = CryptoService.masterRounds()
        account = updated
        persistAccount()
        return nil
    }

    // MARK: Other

    func completeOnboarding() {
        guard var account else { return }
        account.didCompleteOnboarding = true
        self.account = account
        persistAccount()
        phase = .vault
    }

    func logout() {
        syncService?.signOut()
        phase = .auth
        authError = ""
    }

    func verifyMasterPasswordForVaultUnlock(_ password: String) -> Bool {
        guard let account else { return false }
        let clean = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        return CryptoService.verifyMasterPassword(clean, account: account)
    }

    func clearPanicFlag() {
        panicTriggered = false
    }

    func dismissRecoveryKey() {
        pendingRecoveryKey = nil
    }

    var currentEmail: String {
        account?.email ?? "Compte local"
    }

    var hasRecoveryKey: Bool {
        account?.recoveryKeyHash != nil
    }

    // MARK: Private

    private func loadAccount() {
        guard let data = KeychainService.loadOptionalData(for: SecureStoreKey.account) else { return }
        if let decoded = try? JSONDecoder().decode(Account.self, from: data) {
            account = decoded
            phase = decoded.didCompleteOnboarding ? .vault : .onboarding
        }
    }

    private func persistAccount() {
        guard let account else { return }
        if let data = try? JSONEncoder().encode(account) {
            try? KeychainService.save(data: data, key: SecureStoreKey.account)
        }
    }

    private func loadPersistedAttemptState() {
        failedAttempts = KeychainService.loadInt(for: SecureStoreKey.failedAttempts)
        lockoutUntil = KeychainService.loadDate(for: SecureStoreKey.lockoutUntil)
        // Clear expired lockout
        if let lockoutUntil, Date() >= lockoutUntil {
            self.lockoutUntil = nil
            KeychainService.delete(key: SecureStoreKey.lockoutUntil)
        }
    }

    private func registerFailure() {
        failedAttempts += 1
        try? KeychainService.saveInt(failedAttempts, key: SecureStoreKey.failedAttempts)

        if failedAttempts >= 5 {
            // Exponential backoff: 60s → 120s → 180s → … → max 600s (10 min)
            let lockSeconds = min(600, 60 * (failedAttempts - 4))
            let until = Date().addingTimeInterval(TimeInterval(lockSeconds))
            lockoutUntil = until
            try? KeychainService.saveDate(until, key: SecureStoreKey.lockoutUntil)
        }
    }

    private func resetFailedAttempts() {
        failedAttempts = 0
        lockoutUntil = nil
        KeychainService.delete(key: SecureStoreKey.failedAttempts)
        KeychainService.delete(key: SecureStoreKey.lockoutUntil)
    }

    private func migrateAccountHashIfNeeded(password: String) {
        guard var account else { return }
        guard account.passwordHashAlgorithm != "pbkdf2-sha256" else { return }
        account.passwordHash = CryptoService.hashMasterPasswordPBKDF2(
            password, salt: account.passwordSalt, rounds: CryptoService.masterRounds()
        )
        account.passwordHashAlgorithm = "pbkdf2-sha256"
        account.passwordHashRounds = CryptoService.masterRounds()
        self.account = account
        persistAccount()
    }
}
