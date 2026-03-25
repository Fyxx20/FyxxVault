import XCTest
@testable import FyxxVault

final class ModelTests: XCTestCase {

    // MARK: - VaultEntry

    func testVaultEntryDefaultValues() {
        let entry = VaultEntry(
            title: "Test",
            username: "user",
            password: "pass",
            website: "https://test.com",
            notes: ""
        )

        XCTAssertFalse(entry.mfaEnabled)
        XCTAssertNil(entry.mfaType)
        XCTAssertTrue(entry.mfaSecret.isEmpty)
        XCTAssertTrue(entry.folder.isEmpty)
        XCTAssertTrue(entry.tags.isEmpty)
        XCTAssertFalse(entry.isFavorite)
        XCTAssertTrue(entry.customFields.isEmpty)
        XCTAssertTrue(entry.attachments.isEmpty)
        XCTAssertEqual(entry.passwordHistory.count, 1)
        XCTAssertEqual(entry.expirationPolicy, .none)
    }

    func testVaultEntryPasswordHistoryInitialization() {
        let entry = VaultEntry(
            title: "Test",
            username: "user",
            password: "mypassword",
            website: "",
            notes: ""
        )

        XCTAssertEqual(entry.passwordHistory.first?.password, "mypassword")
    }

    func testVaultEntryIsNotExpiredByDefault() {
        let entry = VaultEntry(
            title: "Test",
            username: "user",
            password: "pass",
            website: "",
            notes: ""
        )

        XCTAssertFalse(entry.isExpired)
        XCTAssertFalse(entry.isExpiringSoon)
        XCTAssertNil(entry.daysUntilExpiration)
    }

    func testVaultEntryIsExpired() {
        let entry = VaultEntry(
            title: "Test",
            username: "user",
            password: "pass",
            website: "",
            notes: "",
            expirationPolicy: .days30,
            passwordLastChangedAt: Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        )

        XCTAssertTrue(entry.isExpired)
    }

    func testVaultEntryIsExpiringSoon() {
        let entry = VaultEntry(
            title: "Test",
            username: "user",
            password: "pass",
            website: "",
            notes: "",
            expirationPolicy: .days30,
            passwordLastChangedAt: Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        )

        // 10 days remaining (< 14 days warning threshold)
        XCTAssertFalse(entry.isExpired)
        XCTAssertTrue(entry.isExpiringSoon)
    }

    // MARK: - VaultEntry Codable

    func testVaultEntryCodableRoundTrip() throws {
        let entry = VaultEntry(
            title: "GitHub",
            username: "user@test.com",
            password: "S3cure!Pass",
            website: "https://github.com",
            notes: "Dev account",
            mfaEnabled: true,
            mfaType: .totp,
            mfaSecret: "JBSWY3DPEHPK3PXP",
            folder: "Development",
            tags: ["work", "dev"],
            isFavorite: true,
            customFields: [VaultCustomField(key: "API Key", value: "abc123")]
        )

        let encoded = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(VaultEntry.self, from: encoded)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.title, "GitHub")
        XCTAssertEqual(decoded.username, "user@test.com")
        XCTAssertEqual(decoded.password, "S3cure!Pass")
        XCTAssertEqual(decoded.website, "https://github.com")
        XCTAssertEqual(decoded.notes, "Dev account")
        XCTAssertTrue(decoded.mfaEnabled)
        XCTAssertEqual(decoded.mfaType, .totp)
        XCTAssertEqual(decoded.mfaSecret, "JBSWY3DPEHPK3PXP")
        XCTAssertEqual(decoded.folder, "Development")
        XCTAssertEqual(decoded.tags, ["work", "dev"])
        XCTAssertTrue(decoded.isFavorite)
        XCTAssertEqual(decoded.customFields.count, 1)
        XCTAssertEqual(decoded.customFields.first?.key, "API Key")
    }

    func testVaultEntryDecodesWithMissingOptionalFields() throws {
        // Simulate a minimal JSON (e.g., from an older version)
        let json = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "title": "Test",
            "username": "user",
            "password": "pass",
            "website": "https://test.com",
            "notes": "",
            "createdAt": 1700000000
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(VaultEntry.self, from: json)

        XCTAssertEqual(decoded.title, "Test")
        XCTAssertFalse(decoded.mfaEnabled)
        XCTAssertNil(decoded.mfaType)
        XCTAssertTrue(decoded.mfaSecret.isEmpty)
        XCTAssertTrue(decoded.folder.isEmpty)
        XCTAssertTrue(decoded.tags.isEmpty)
        XCTAssertFalse(decoded.isFavorite)
        XCTAssertEqual(decoded.expirationPolicy, .none)
    }

    // MARK: - VaultDatabase Codable

    func testVaultDatabaseCodableRoundTrip() throws {
        let entry1 = VaultEntry(title: "A", username: "a", password: "p", website: "", notes: "")
        let entry2 = VaultEntry(title: "B", username: "b", password: "q", website: "", notes: "")
        let trash = VaultTrashItem(id: UUID(), entry: entry1, deletedAt: Date(), expiresAt: Date().addingTimeInterval(86400 * 30))
        let log = ActivityLogItem(action: "Test", target: "Unit test")

        let db = VaultDatabase(entries: [entry1, entry2], trash: [trash], activityLog: [log])
        let encoded = try JSONEncoder().encode(db)
        let decoded = try JSONDecoder().decode(VaultDatabase.self, from: encoded)

        XCTAssertEqual(decoded.schemaVersion, 3)
        XCTAssertEqual(decoded.entries.count, 2)
        XCTAssertEqual(decoded.trash.count, 1)
        XCTAssertEqual(decoded.activityLog.count, 1)
    }

    // MARK: - Account Codable

    func testAccountCodableRoundTrip() throws {
        let account = Account(
            email: "test@test.com",
            passwordSalt: Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
            passwordHash: "abcdef1234567890",
            passwordHashAlgorithm: "pbkdf2-sha256",
            passwordHashRounds: 210_000,
            didCompleteOnboarding: true,
            recoveryKeyHash: "recovery_hash",
            recoveryKeySalt: Data([16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1])
        )

        let encoded = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(Account.self, from: encoded)

        XCTAssertEqual(decoded.email, "test@test.com")
        XCTAssertEqual(decoded.passwordHashAlgorithm, "pbkdf2-sha256")
        XCTAssertEqual(decoded.passwordHashRounds, 210_000)
        XCTAssertTrue(decoded.didCompleteOnboarding)
        XCTAssertEqual(decoded.recoveryKeyHash, "recovery_hash")
    }

    func testAccountDecodesLegacyFormat() throws {
        // Legacy accounts don't have passwordHashAlgorithm or passwordHashRounds
        let json = """
        {
            "email": "old@test.com",
            "passwordSalt": "AQIDBA==",
            "passwordHash": "oldhash",
            "didCompleteOnboarding": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(Account.self, from: json)

        XCTAssertEqual(decoded.email, "old@test.com")
        XCTAssertEqual(decoded.passwordHashAlgorithm, "sha256-salt") // Default for legacy
        XCTAssertEqual(decoded.passwordHashRounds, 0) // Default for legacy
        XCTAssertNil(decoded.recoveryKeyHash)
    }

    // MARK: - BackupEnvelope Codable

    func testBackupEnvelopeCodableRoundTrip() throws {
        let envelope = BackupEnvelope(
            version: 2,
            createdAt: Date(),
            salt: Data([1, 2, 3, 4]),
            cipherCombined: Data([5, 6, 7, 8]),
            signature: Data([9, 10, 11, 12])
        )

        let encoded = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(BackupEnvelope.self, from: encoded)

        XCTAssertEqual(decoded.version, 2)
        XCTAssertEqual(decoded.salt, envelope.salt)
        XCTAssertEqual(decoded.cipherCombined, envelope.cipherCombined)
        XCTAssertEqual(decoded.signature, envelope.signature)
    }
}
