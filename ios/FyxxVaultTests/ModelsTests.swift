import XCTest
@testable import FyxxVault

final class ModelsTests: XCTestCase {

    // MARK: - VaultEntry Codable

    func testVaultEntryCodable() throws {
        let entry = VaultEntry(
            title: "GitHub",
            username: "dev@example.com",
            password: "gh-p@ss123",
            website: "https://github.com",
            notes: "Work account",
            mfaEnabled: true,
            mfaType: .totp,
            mfaSecret: "JBSWY3DPEHPK3PXP",
            folder: "Dev",
            tags: ["work", "dev"],
            isFavorite: true,
            customFields: [VaultCustomField(key: "API Key", value: "abc123")],
            category: .login
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VaultEntry.self, from: data)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.title, entry.title)
        XCTAssertEqual(decoded.username, entry.username)
        XCTAssertEqual(decoded.password, entry.password)
        XCTAssertEqual(decoded.website, entry.website)
        XCTAssertEqual(decoded.notes, entry.notes)
        XCTAssertEqual(decoded.mfaEnabled, entry.mfaEnabled)
        XCTAssertEqual(decoded.mfaType, entry.mfaType)
        XCTAssertEqual(decoded.mfaSecret, entry.mfaSecret)
        XCTAssertEqual(decoded.folder, entry.folder)
        XCTAssertEqual(decoded.tags, entry.tags)
        XCTAssertEqual(decoded.isFavorite, entry.isFavorite)
        XCTAssertEqual(decoded.customFields.count, 1)
        XCTAssertEqual(decoded.customFields[0].key, "API Key")
        XCTAssertEqual(decoded.customFields[0].value, "abc123")
        XCTAssertEqual(decoded.category, .login)
    }

    // MARK: - Backward Compatibility (no category field)

    func testVaultEntryBackwardCompatibility() throws {
        // JSON without the "category" key -- must default to .login
        let json = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "title": "OldEntry",
            "username": "user",
            "password": "pass",
            "website": "https://old.com",
            "notes": "",
            "createdAt": 0
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let entry = try decoder.decode(VaultEntry.self, from: json)

        XCTAssertEqual(entry.category, .login, "Missing category must default to .login")
        XCTAssertEqual(entry.title, "OldEntry")
        XCTAssertEqual(entry.folder, "", "Missing folder must default to empty string")
        XCTAssertFalse(entry.isFavorite, "Missing isFavorite must default to false")
        XCTAssertFalse(entry.mfaEnabled, "Missing mfaEnabled must default to false")
    }

    // MARK: - VaultDatabase v3 to v4

    func testVaultDatabaseV3ToV4() throws {
        let json = """
        {
            "schemaVersion": 3,
            "entries": [
                {
                    "id": "550E8400-E29B-41D4-A716-446655440001",
                    "title": "LegacyEntry",
                    "username": "legacy",
                    "password": "oldpass",
                    "website": "https://legacy.com",
                    "notes": "migrated",
                    "createdAt": 1000000
                }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let db = try decoder.decode(VaultDatabase.self, from: json)

        XCTAssertEqual(db.schemaVersion, 3)
        XCTAssertEqual(db.entries.count, 1)
        XCTAssertEqual(db.entries[0].category, .login, "v3 entries without category must default to .login")
        XCTAssertTrue(db.trash.isEmpty, "Missing trash must default to empty")
        XCTAssertTrue(db.activityLog.isEmpty, "Missing activityLog must default to empty")
    }

    // MARK: - Password Expiration

    func testPasswordExpiration() {
        // Password changed 31 days ago with a 30-day policy
        let changedDate = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        let entry = VaultEntry(
            title: "Expired",
            username: "u",
            password: "p",
            website: "",
            notes: "",
            expirationPolicy: .days30,
            passwordLastChangedAt: changedDate
        )

        XCTAssertTrue(entry.isExpired, "Password changed 31 days ago with 30-day policy must be expired")
        XCTAssertFalse(entry.isExpiringSoon, "Already expired password must not be 'expiring soon'")
    }

    func testPasswordExpiringSoon() {
        // Password changed 20 days ago with 30-day policy (expires in 10 days, within 14-day warning)
        let changedDate = Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        let entry = VaultEntry(
            title: "ExpiringSoon",
            username: "u",
            password: "p",
            website: "",
            notes: "",
            expirationPolicy: .days30,
            passwordLastChangedAt: changedDate
        )

        XCTAssertFalse(entry.isExpired, "Password with 10 days left must not be expired")
        XCTAssertTrue(entry.isExpiringSoon, "Password expiring in 10 days must be 'expiring soon'")
    }

    func testPasswordNotExpiring() {
        // No expiration policy
        let entry = VaultEntry(
            title: "NoExpiry",
            username: "u",
            password: "p",
            website: "",
            notes: "",
            expirationPolicy: .none
        )

        XCTAssertFalse(entry.isExpired)
        XCTAssertFalse(entry.isExpiringSoon)
        XCTAssertNil(entry.daysUntilExpiration)
    }

    // MARK: - VaultCategory

    func testVaultCategoryAllCases() {
        let allCases = VaultCategory.allCases
        XCTAssertEqual(allCases.count, 8, "There must be 8 vault categories")

        for category in allCases {
            XCTAssertFalse(category.label.isEmpty, "\(category.rawValue) must have a non-empty label")
            XCTAssertFalse(category.iconName.isEmpty, "\(category.rawValue) must have a non-empty icon name")
        }
    }

    // MARK: - Trash Item Expiration

    func testTrashItemExpiration() {
        let entry = VaultEntry(title: "Deleted", username: "u", password: "p", website: "", notes: "")
        let now = Date()
        let expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: now)!

        let trashItem = VaultTrashItem(
            id: entry.id,
            entry: entry,
            deletedAt: now,
            expiresAt: expiresAt
        )

        let daysDiff = Calendar.current.dateComponents([.day], from: trashItem.deletedAt, to: trashItem.expiresAt).day!
        XCTAssertEqual(daysDiff, 30, "Trash item must expire 30 days after deletion")
    }

    // MARK: - Account Codable

    func testAccountCodable() throws {
        let account = Account(
            email: "test@fyxxvault.com",
            passwordSalt: Data("saltsaltsaltsalt".utf8),
            passwordHash: "abc123hash",
            passwordHashAlgorithm: "pbkdf2-sha256",
            passwordHashRounds: 210_000,
            didCompleteOnboarding: true
        )

        let data = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(Account.self, from: data)

        XCTAssertEqual(decoded.email, account.email)
        XCTAssertEqual(decoded.passwordHash, account.passwordHash)
        XCTAssertEqual(decoded.passwordHashAlgorithm, account.passwordHashAlgorithm)
        XCTAssertEqual(decoded.passwordHashRounds, account.passwordHashRounds)
        XCTAssertEqual(decoded.didCompleteOnboarding, true)
    }

    // MARK: - PasswordStrength enum

    func testPasswordStrengthRawValues() {
        XCTAssertEqual(PasswordStrength.faible.rawValue, "Faible")
        XCTAssertEqual(PasswordStrength.moyen.rawValue, "Moyen")
        XCTAssertEqual(PasswordStrength.fort.rawValue, "Fort")
        XCTAssertEqual(PasswordStrength.excellent.rawValue, "Excellent")
    }
}
