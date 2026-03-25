import XCTest
import CryptoKit
@testable import FyxxVault

final class CloudKeyManagerTests: XCTestCase {

    // MARK: - VEK Generation

    func testVEKGeneration() {
        let vek = CloudKeyManager.generateVEK()
        XCTAssertEqual(vek.count, 32, "VEK must be 32 bytes (256 bits)")
    }

    func testVEKGenerationRandomness() {
        let vek1 = CloudKeyManager.generateVEK()
        let vek2 = CloudKeyManager.generateVEK()
        XCTAssertNotEqual(vek1, vek2, "Two VEKs must differ (probabilistically)")
    }

    // MARK: - VEK Wrap / Unwrap

    func testVEKWrapUnwrap() throws {
        let vek = CloudKeyManager.generateVEK()
        let kek = makeKEK(password: "StrongMaster!123")

        let wrapped = try CloudKeyManager.wrapVEK(vek, with: kek)
        let unwrapped = try CloudKeyManager.unwrapVEK(wrapped, with: kek)

        XCTAssertEqual(unwrapped, vek, "Unwrapped VEK must match original")
    }

    func testVEKUnwrapWrongKEK() throws {
        let vek = CloudKeyManager.generateVEK()
        let kekCorrect = makeKEK(password: "CorrectPassword!")
        let kekWrong = makeKEK(password: "WrongPassword!!!")

        let wrapped = try CloudKeyManager.wrapVEK(vek, with: kekCorrect)

        XCTAssertThrowsError(try CloudKeyManager.unwrapVEK(wrapped, with: kekWrong),
                             "Unwrapping with wrong KEK must throw")
    }

    // MARK: - KEK Derivation

    func testKEKDeterministic() {
        let salt = CryptoService.makeSalt()
        let kek1 = CloudKeyManager.deriveKEK(masterPassword: "SamePassword!1", salt: salt, rounds: 1_000)
        let kek2 = CloudKeyManager.deriveKEK(masterPassword: "SamePassword!1", salt: salt, rounds: 1_000)

        XCTAssertEqual(kek1, kek2, "Same password and salt must produce the same KEK")
    }

    func testKEKDifferentPasswords() {
        let salt = CryptoService.makeSalt()
        let kekA = CloudKeyManager.deriveKEK(masterPassword: "PasswordA!1234", salt: salt, rounds: 1_000)
        let kekB = CloudKeyManager.deriveKEK(masterPassword: "PasswordB!5678", salt: salt, rounds: 1_000)

        XCTAssertNotEqual(kekA, kekB, "Different passwords must produce different KEKs")
    }

    // MARK: - Entry Encrypt / Decrypt

    func testEntryEncryptDecrypt() throws {
        let vek = CloudKeyManager.generateVEK()

        let entry = VaultEntry(
            title: "Test Entry",
            username: "user@example.com",
            password: "SuperSecret123!",
            website: "https://example.com",
            notes: "Some notes here",
            mfaEnabled: true,
            mfaType: .totp,
            mfaSecret: "JBSWY3DPEHPK3PXP",
            folder: "Work",
            tags: ["important"],
            isFavorite: true,
            category: .login
        )

        let encrypted = try CloudKeyManager.encryptEntry(entry, with: vek)
        let decrypted = try CloudKeyManager.decryptEntry(encrypted, with: vek)

        XCTAssertEqual(decrypted.title, entry.title)
        XCTAssertEqual(decrypted.username, entry.username)
        XCTAssertEqual(decrypted.password, entry.password)
        XCTAssertEqual(decrypted.website, entry.website)
        XCTAssertEqual(decrypted.notes, entry.notes)
        XCTAssertEqual(decrypted.mfaEnabled, entry.mfaEnabled)
        XCTAssertEqual(decrypted.mfaType, entry.mfaType)
        XCTAssertEqual(decrypted.mfaSecret, entry.mfaSecret)
        XCTAssertEqual(decrypted.folder, entry.folder)
        XCTAssertEqual(decrypted.tags, entry.tags)
        XCTAssertEqual(decrypted.isFavorite, entry.isFavorite)
        XCTAssertEqual(decrypted.category, entry.category)
    }

    func testEntryDecryptWrongKey() throws {
        let vekCorrect = CloudKeyManager.generateVEK()
        let vekWrong = CloudKeyManager.generateVEK()

        let entry = VaultEntry(title: "Secret", username: "u", password: "p", website: "w", notes: "n")
        let encrypted = try CloudKeyManager.encryptEntry(entry, with: vekCorrect)

        XCTAssertThrowsError(try CloudKeyManager.decryptEntry(encrypted, with: vekWrong),
                             "Decrypting with wrong VEK must throw")
    }

    // MARK: - Helpers

    private func makeKEK(password: String) -> Data {
        let salt = Data("test-salt-16bytes".utf8)
        return CloudKeyManager.deriveKEK(masterPassword: password, salt: salt, rounds: 1_000)
    }
}
