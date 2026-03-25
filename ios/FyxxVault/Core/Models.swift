import Foundation
import CryptoKit
import SwiftUI

// MARK: - Enums

enum SessionPhase {
    case auth
    case onboarding
    case vault
}

enum VaultMFAType: String, Codable, CaseIterable, Identifiable {
    case totp = "TOTP"
    case sms = "SMS"
    case email = "Email"
    var id: String { rawValue }
}

enum PasswordStrength: String {
    case faible = "Faible"
    case moyen = "Moyen"
    case fort = "Fort"
    case excellent = "Excellent"

    var color: SwiftUI.Color {
        switch self {
        case .faible: return .red
        case .moyen: return .orange
        case .fort: return .green
        case .excellent: return SwiftUI.Color(red: 67/255, green: 215/255, blue: 208/255)
        }
    }
}

enum VaultSortMode: String, CaseIterable, Identifiable {
    case recent = "Tri: récent"
    case alphabetical = "Tri: A-Z"
    case strength = "Tri: robustesse"
    var id: String { rawValue }
}

enum VaultFilterMode: String, CaseIterable, Identifiable {
    case all = "Tous"
    case favorites = "Favoris"
    case weak = "À renforcer"
    case mfa = "MFA"
    case expired = "Expirés"
    var id: String { rawValue }
}

enum PasswordGenerationMode: String, CaseIterable, Identifiable {
    case random = "Aléatoire"
    case passphrase = "Passphrase"
    var id: String { rawValue }
}

enum PasswordExpirationPolicy: Int, CaseIterable, Identifiable, Codable {
    case none = 0
    case days30 = 30
    case days60 = 60
    case days90 = 90
    case days180 = 180
    case days365 = 365

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .none: return "Jamais"
        case .days30: return "30 jours"
        case .days60: return "60 jours"
        case .days90: return "90 jours"
        case .days180: return "6 mois"
        case .days365: return "1 an"
        }
    }
}

// MARK: - Security Error

enum SecurityError: Error {
    case accountNotFound
    case encryptionFailure
    case decryptionFailure
    case tampered
    case weakPassword(String)
}

enum BackupError: Error {
    case invalidPassphrase
    case tamperedData
    case malformedData
}

// MARK: - Account Model

struct Account: Codable {
    var email: String
    var passwordSalt: Data
    var passwordHash: String
    var passwordHashAlgorithm: String
    var passwordHashRounds: Int
    var panicSalt: Data?
    var panicHash: String?
    var didCompleteOnboarding: Bool
    /// PBKDF2-SHA256 hash of the recovery key
    var recoveryKeyHash: String?
    var recoveryKeySalt: Data?

    private enum CodingKeys: String, CodingKey {
        case email, passwordSalt, passwordHash, passwordHashAlgorithm, passwordHashRounds
        case panicSalt, panicHash, didCompleteOnboarding
        case recoveryKeyHash, recoveryKeySalt
    }

    init(
        email: String,
        passwordSalt: Data,
        passwordHash: String,
        passwordHashAlgorithm: String = "pbkdf2-sha256",
        passwordHashRounds: Int = 210_000,
        panicSalt: Data? = nil,
        panicHash: String? = nil,
        didCompleteOnboarding: Bool,
        recoveryKeyHash: String? = nil,
        recoveryKeySalt: Data? = nil
    ) {
        self.email = email
        self.passwordSalt = passwordSalt
        self.passwordHash = passwordHash
        self.passwordHashAlgorithm = passwordHashAlgorithm
        self.passwordHashRounds = passwordHashRounds
        self.panicSalt = panicSalt
        self.panicHash = panicHash
        self.didCompleteOnboarding = didCompleteOnboarding
        self.recoveryKeyHash = recoveryKeyHash
        self.recoveryKeySalt = recoveryKeySalt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = try container.decode(String.self, forKey: .email)
        passwordSalt = try container.decode(Data.self, forKey: .passwordSalt)
        passwordHash = try container.decode(String.self, forKey: .passwordHash)
        passwordHashAlgorithm = try container.decodeIfPresent(String.self, forKey: .passwordHashAlgorithm) ?? "sha256-salt"
        passwordHashRounds = try container.decodeIfPresent(Int.self, forKey: .passwordHashRounds) ?? 0
        panicSalt = try container.decodeIfPresent(Data.self, forKey: .panicSalt)
        panicHash = try container.decodeIfPresent(String.self, forKey: .panicHash)
        didCompleteOnboarding = try container.decode(Bool.self, forKey: .didCompleteOnboarding)
        recoveryKeyHash = try container.decodeIfPresent(String.self, forKey: .recoveryKeyHash)
        recoveryKeySalt = try container.decodeIfPresent(Data.self, forKey: .recoveryKeySalt)
    }
}

// MARK: - Vault Entry Models

struct PasswordVersion: Codable, Hashable, Identifiable {
    var id: UUID
    var password: String
    var createdAt: Date

    init(id: UUID = UUID(), password: String, createdAt: Date = Date()) {
        self.id = id
        self.password = password
        self.createdAt = createdAt
    }
}

struct VaultCustomField: Codable, Hashable, Identifiable {
    var id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

struct SecureAttachment: Codable, Hashable, Identifiable {
    var id: UUID
    var fileName: String
    var mimeType: String
    var base64Data: String
    var createdAt: Date

    init(id: UUID = UUID(), fileName: String, mimeType: String, base64Data: String, createdAt: Date = Date()) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.base64Data = base64Data
        self.createdAt = createdAt
    }
}

struct VaultEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var username: String
    var password: String
    var website: String
    var notes: String
    var mfaEnabled: Bool
    var mfaType: VaultMFAType?
    var mfaSecret: String
    var folder: String
    var tags: [String]
    var isFavorite: Bool
    var customFields: [VaultCustomField]
    var attachments: [SecureAttachment]
    var passwordHistory: [PasswordVersion]
    var createdAt: Date
    var lastModifiedAt: Date
    var expirationPolicy: PasswordExpirationPolicy
    var passwordLastChangedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, title, username, password, website, notes, mfaEnabled, mfaType, mfaSecret
        case folder, tags, isFavorite, customFields, attachments, passwordHistory, createdAt
        case lastModifiedAt, expirationPolicy, passwordLastChangedAt
    }

    init(
        id: UUID = UUID(),
        title: String,
        username: String,
        password: String,
        website: String,
        notes: String,
        mfaEnabled: Bool = false,
        mfaType: VaultMFAType? = nil,
        mfaSecret: String = "",
        folder: String = "",
        tags: [String] = [],
        isFavorite: Bool = false,
        customFields: [VaultCustomField] = [],
        attachments: [SecureAttachment] = [],
        passwordHistory: [PasswordVersion] = [],
        createdAt: Date = Date(),
        lastModifiedAt: Date = Date(),
        expirationPolicy: PasswordExpirationPolicy = .none,
        passwordLastChangedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.website = website
        self.notes = notes
        self.mfaEnabled = mfaEnabled
        self.mfaType = mfaType
        self.mfaSecret = mfaSecret
        self.folder = folder
        self.tags = tags
        self.isFavorite = isFavorite
        self.customFields = customFields
        self.attachments = attachments
        self.passwordHistory = passwordHistory.isEmpty
            ? [PasswordVersion(password: password, createdAt: createdAt)]
            : passwordHistory
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
        self.expirationPolicy = expirationPolicy
        self.passwordLastChangedAt = passwordLastChangedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        username = try container.decode(String.self, forKey: .username)
        password = try container.decode(String.self, forKey: .password)
        website = try container.decode(String.self, forKey: .website)
        notes = try container.decode(String.self, forKey: .notes)
        mfaEnabled = try container.decodeIfPresent(Bool.self, forKey: .mfaEnabled) ?? false
        mfaType = try container.decodeIfPresent(VaultMFAType.self, forKey: .mfaType)
        mfaSecret = try container.decodeIfPresent(String.self, forKey: .mfaSecret) ?? ""
        folder = try container.decodeIfPresent(String.self, forKey: .folder) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        customFields = try container.decodeIfPresent([VaultCustomField].self, forKey: .customFields) ?? []
        attachments = try container.decodeIfPresent([SecureAttachment].self, forKey: .attachments) ?? []
        passwordHistory = try container.decodeIfPresent([PasswordVersion].self, forKey: .passwordHistory) ?? [PasswordVersion(password: password)]
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastModifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastModifiedAt) ?? createdAt
        expirationPolicy = try container.decodeIfPresent(PasswordExpirationPolicy.self, forKey: .expirationPolicy) ?? .none
        passwordLastChangedAt = try container.decodeIfPresent(Date.self, forKey: .passwordLastChangedAt) ?? createdAt
    }

    /// True if expiration policy is set and the password is past its deadline
    var isExpired: Bool {
        guard expirationPolicy != .none else { return false }
        let deadline = Calendar.current.date(byAdding: .day, value: expirationPolicy.rawValue, to: passwordLastChangedAt) ?? .distantFuture
        return Date() >= deadline
    }

    /// True if expiration is within 14 days
    var isExpiringSoon: Bool {
        guard expirationPolicy != .none, !isExpired else { return false }
        let deadline = Calendar.current.date(byAdding: .day, value: expirationPolicy.rawValue, to: passwordLastChangedAt) ?? .distantFuture
        let warning = Calendar.current.date(byAdding: .day, value: -14, to: deadline) ?? deadline
        return Date() >= warning
    }

    var daysUntilExpiration: Int? {
        guard expirationPolicy != .none else { return nil }
        let deadline = Calendar.current.date(byAdding: .day, value: expirationPolicy.rawValue, to: passwordLastChangedAt) ?? .distantFuture
        return Calendar.current.dateComponents([.day], from: Date(), to: deadline).day
    }
}

struct VaultTrashItem: Identifiable, Codable, Hashable {
    var id: UUID
    var entry: VaultEntry
    var deletedAt: Date
    var expiresAt: Date
}

struct ActivityLogItem: Codable, Hashable, Identifiable {
    var id: UUID
    var date: Date
    var action: String
    var target: String

    init(id: UUID = UUID(), date: Date = Date(), action: String, target: String) {
        self.id = id
        self.date = date
        self.action = action
        self.target = target
    }
}

struct SecurityAudit {
    var score: Int
    var weakCount: Int
    var reusedCount: Int
    var withoutMFACount: Int
    var expiredCount: Int
    var recommendations: [String]
}

// MARK: - Vault Database (v3)

struct VaultDatabase: Codable {
    var schemaVersion: Int
    var entries: [VaultEntry]
    var trash: [VaultTrashItem]
    var activityLog: [ActivityLogItem]
    /// HMAC-SHA256 over the serialised entries+trash+log as integrity check
    var databaseHMAC: String?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, entries, trash, activityLog, databaseHMAC
    }

    init(entries: [VaultEntry], trash: [VaultTrashItem], activityLog: [ActivityLogItem], schemaVersion: Int = 3) {
        self.schemaVersion = schemaVersion
        self.entries = entries
        self.trash = trash
        self.activityLog = activityLog
        self.databaseHMAC = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        entries = try container.decodeIfPresent([VaultEntry].self, forKey: .entries) ?? []
        trash = try container.decodeIfPresent([VaultTrashItem].self, forKey: .trash) ?? []
        activityLog = try container.decodeIfPresent([ActivityLogItem].self, forKey: .activityLog) ?? []
        databaseHMAC = try container.decodeIfPresent(String.self, forKey: .databaseHMAC)
    }
}

// MARK: - Password Policy

struct PasswordPolicy {
    var length: Int = 18
    var includeUppercase: Bool = true
    var includeLowercase: Bool = true
    var includeNumbers: Bool = true
    var includeSymbols: Bool = true
    var mode: PasswordGenerationMode = .random
    var wordsCount: Int = 4
}

// MARK: - Backup

struct BackupEnvelope: Codable {
    var version: Int
    var createdAt: Date
    var salt: Data
    var cipherCombined: Data
    var signature: Data
}

// MARK: - TOTP Snapshot

struct TOTPSnapshot {
    let code: String
    let remainingSeconds: Int
}

// MARK: - Settings Keys

enum SettingsKey {
    static let autoLockEnabled = "fyxxvault.autolock.enabled"
    static let autoLockMinutes = "fyxxvault.autolock.minutes"
    static let biometricUnlock = "fyxxvault.biometric.unlock"
    static let clipboardAutoClear = "fyxxvault.clipboard.autoclear"
    static let clipboardDelay = "fyxxvault.clipboard.clear.delay"
    static let keyRotationDate = "fyxxvault.key.rotation.date"
    static let localSnapshotDate = "fyxxvault.local.snapshot.date"
}

// MARK: - Secure Store Keys

enum SecureStoreKey {
    static let account = "fyxxvault.account"
    static let vaultSymmetricKey = "fyxxvault.vault.symmetric.key"
    static let failedAttempts = "fyxxvault.failed.attempts"
    static let lockoutUntil = "fyxxvault.lockout.until"
    static let recoveryKey = "fyxxvault.recovery.key"
}
