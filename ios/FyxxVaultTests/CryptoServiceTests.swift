import XCTest
import CryptoKit
@testable import FyxxVault

final class CryptoServiceTests: XCTestCase {

    // MARK: - AES-256-GCM Encrypt / Decrypt

    func testEncryptDecryptRoundTrip() throws {
        let plaintext = "Hello, FyxxVault! 🔐".data(using: .utf8)!
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let encrypted = try CryptoService.encrypt(data: plaintext, with: key)
        let decrypted = try CryptoService.decrypt(data: encrypted, with: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptProducesDifferentCiphertextEachTime() throws {
        let plaintext = Data("same input".utf8)
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let a = try CryptoService.encrypt(data: plaintext, with: key)
        let b = try CryptoService.encrypt(data: plaintext, with: key)

        // AES-GCM uses a random nonce, so two encryptions should differ
        XCTAssertNotEqual(a, b)
    }

    func testDecryptWithWrongKeyFails() throws {
        let plaintext = Data("secret".utf8)
        let correctKey = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let wrongKey = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let encrypted = try CryptoService.encrypt(data: plaintext, with: correctKey)

        XCTAssertThrowsError(try CryptoService.decrypt(data: encrypted, with: wrongKey))
    }

    func testEncryptDecryptEmptyData() throws {
        let plaintext = Data()
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let encrypted = try CryptoService.encrypt(data: plaintext, with: key)
        let decrypted = try CryptoService.decrypt(data: encrypted, with: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptDecryptLargePayload() throws {
        // 1 MB of random data
        let plaintext = Data((0..<1_000_000).map { _ in UInt8.random(in: 0...255) })
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let encrypted = try CryptoService.encrypt(data: plaintext, with: key)
        let decrypted = try CryptoService.decrypt(data: encrypted, with: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    // MARK: - HMAC-SHA256

    func testHMACSHA256Deterministic() {
        let data = Data("test data".utf8)
        let key = Data("test key 32 bytes long padding!!".utf8)

        let hmac1 = CryptoService.hmacSHA256(data: data, key: key)
        let hmac2 = CryptoService.hmacSHA256(data: data, key: key)

        XCTAssertEqual(hmac1, hmac2)
        XCTAssertEqual(hmac1.count, 32) // SHA-256 produces 32 bytes
    }

    func testHMACSHA256DifferentKeysProduceDifferentResults() {
        let data = Data("test data".utf8)
        let key1 = Data("key one 32 bytes long padding!!!".utf8)
        let key2 = Data("key two 32 bytes long padding!!!".utf8)

        let hmac1 = CryptoService.hmacSHA256(data: data, key: key1)
        let hmac2 = CryptoService.hmacSHA256(data: data, key: key2)

        XCTAssertNotEqual(hmac1, hmac2)
    }

    // MARK: - Vault File Format (FYXV header + HMAC)

    func testWrapUnwrapVaultData() throws {
        let ciphertext = Data("encrypted vault data".utf8)
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let wrapped = CryptoService.wrapVaultData(ciphertext: ciphertext, keyData: key)

        // Check magic bytes "FYXV"
        XCTAssertEqual(Array(wrapped.prefix(4)), [0x46, 0x59, 0x58, 0x56])

        // Unwrap should return the original ciphertext
        let unwrapped = try CryptoService.unwrapVaultData(wrapped, keyData: key)
        XCTAssertEqual(unwrapped, ciphertext)
    }

    func testUnwrapTamperedDataThrows() {
        let ciphertext = Data("encrypted vault data".utf8)
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        var wrapped = CryptoService.wrapVaultData(ciphertext: ciphertext, keyData: key)

        // Tamper with the ciphertext portion (after 4-byte magic + 32-byte HMAC)
        if wrapped.count > 36 {
            wrapped[36] ^= 0xFF
        }

        XCTAssertThrowsError(try CryptoService.unwrapVaultData(wrapped, keyData: key)) { error in
            XCTAssertEqual(error as? SecurityError, .tampered)
        }
    }

    func testUnwrapWithWrongKeyThrows() {
        let ciphertext = Data("encrypted vault data".utf8)
        let correctKey = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let wrongKey = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let wrapped = CryptoService.wrapVaultData(ciphertext: ciphertext, keyData: correctKey)

        XCTAssertThrowsError(try CryptoService.unwrapVaultData(wrapped, keyData: wrongKey))
    }

    func testUnwrapTooShortDataThrows() {
        let shortData = Data([0x46, 0x59, 0x58, 0x56]) // Just magic, no HMAC
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        XCTAssertThrowsError(try CryptoService.unwrapVaultData(shortData, keyData: key))
    }

    // MARK: - PBKDF2-SHA256

    func testPBKDF2Deterministic() {
        let password = Data("MyMasterPassword!".utf8)
        let salt = Data("fixed_salt_16byt".utf8)

        let derived1 = CryptoService.pbkdf2SHA256(password: password, salt: salt, rounds: 1000, keyLength: 32)
        let derived2 = CryptoService.pbkdf2SHA256(password: password, salt: salt, rounds: 1000, keyLength: 32)

        XCTAssertEqual(derived1, derived2)
        XCTAssertEqual(derived1.count, 32)
    }

    func testPBKDF2DifferentPasswordsProduceDifferentKeys() {
        let salt = Data("fixed_salt_16byt".utf8)

        let key1 = CryptoService.pbkdf2SHA256(password: Data("password1".utf8), salt: salt, rounds: 1000, keyLength: 32)
        let key2 = CryptoService.pbkdf2SHA256(password: Data("password2".utf8), salt: salt, rounds: 1000, keyLength: 32)

        XCTAssertNotEqual(key1, key2)
    }

    func testPBKDF2DifferentSaltsProduceDifferentKeys() {
        let password = Data("same_password".utf8)

        let key1 = CryptoService.pbkdf2SHA256(password: password, salt: Data("salt_one_16bytes".utf8), rounds: 1000, keyLength: 32)
        let key2 = CryptoService.pbkdf2SHA256(password: password, salt: Data("salt_two_16bytes".utf8), rounds: 1000, keyLength: 32)

        XCTAssertNotEqual(key1, key2)
    }

    // MARK: - Master Password Hashing

    func testHashMasterPasswordDeterministic() {
        let salt = CryptoService.makeSalt()
        let hash1 = CryptoService.hashMasterPasswordPBKDF2("TestPass123!", salt: salt)
        let hash2 = CryptoService.hashMasterPasswordPBKDF2("TestPass123!", salt: salt)

        XCTAssertEqual(hash1, hash2)
        XCTAssertFalse(hash1.isEmpty)
    }

    func testVerifyMasterPasswordCorrect() {
        let password = "MySecureP@ss1"
        let salt = CryptoService.makeSalt()
        let hash = CryptoService.hashMasterPasswordPBKDF2(password, salt: salt)

        let account = Account(
            email: "test@test.com",
            passwordSalt: salt,
            passwordHash: hash,
            passwordHashAlgorithm: "pbkdf2-sha256",
            passwordHashRounds: 210_000,
            didCompleteOnboarding: true
        )

        XCTAssertTrue(CryptoService.verifyMasterPassword(password, account: account))
    }

    func testVerifyMasterPasswordWrong() {
        let salt = CryptoService.makeSalt()
        let hash = CryptoService.hashMasterPasswordPBKDF2("correct_password!", salt: salt)

        let account = Account(
            email: "test@test.com",
            passwordSalt: salt,
            passwordHash: hash,
            passwordHashAlgorithm: "pbkdf2-sha256",
            passwordHashRounds: 210_000,
            didCompleteOnboarding: true
        )

        XCTAssertFalse(CryptoService.verifyMasterPassword("wrong_password!", account: account))
    }

    // MARK: - Salt Generation

    func testMakeSaltProducesUniqueSalts() {
        let salt1 = CryptoService.makeSalt()
        let salt2 = CryptoService.makeSalt()

        XCTAssertEqual(salt1.count, 16)
        XCTAssertEqual(salt2.count, 16)
        XCTAssertNotEqual(salt1, salt2)
    }

    // MARK: - Recovery Key

    func testRecoveryKeyFormat() {
        let raw = CryptoService.generateRecoveryKey()
        XCTAssertEqual(raw.count, 32)

        let formatted = CryptoService.formatRecoveryKey(raw)
        // Should be 8 groups of 4 chars separated by dashes
        let groups = formatted.split(separator: "-")
        XCTAssertEqual(groups.count, 8)
        for group in groups {
            XCTAssertEqual(group.count, 4)
        }
    }

    func testRecoveryKeyVerification() {
        let raw = CryptoService.generateRecoveryKey()
        let salt = CryptoService.makeSalt()
        let hash = CryptoService.hashRecoveryKey(raw, salt: salt)

        let account = Account(
            email: "test@test.com",
            passwordSalt: CryptoService.makeSalt(),
            passwordHash: "dummy",
            didCompleteOnboarding: true,
            recoveryKeyHash: hash,
            recoveryKeySalt: salt
        )

        XCTAssertTrue(CryptoService.verifyRecoveryKey(raw, account: account))
        XCTAssertFalse(CryptoService.verifyRecoveryKey("WRONG_KEY_WRONG_KEY_WRONG_KEY_12", account: account))
    }

    func testRecoveryKeyVerificationWithDashes() {
        let raw = CryptoService.generateRecoveryKey()
        let formatted = CryptoService.formatRecoveryKey(raw)
        let salt = CryptoService.makeSalt()
        let hash = CryptoService.hashRecoveryKey(raw, salt: salt)

        let account = Account(
            email: "test@test.com",
            passwordSalt: CryptoService.makeSalt(),
            passwordHash: "dummy",
            didCompleteOnboarding: true,
            recoveryKeyHash: hash,
            recoveryKeySalt: salt
        )

        // Should work with dashes (formatted version)
        XCTAssertTrue(CryptoService.verifyRecoveryKey(formatted, account: account))
    }

    // MARK: - Full End-to-End Vault Round Trip

    func testFullVaultRoundTrip() throws {
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        // Create a vault entry
        let entry = VaultEntry(
            title: "GitHub",
            username: "user@example.com",
            password: "SuperSecure!123",
            website: "https://github.com",
            notes: "My dev account"
        )
        let db = VaultDatabase(entries: [entry], trash: [], activityLog: [])
        let payload = try JSONEncoder().encode(db)

        // Encrypt
        let ciphertext = try CryptoService.encrypt(data: payload, with: key)

        // Wrap with HMAC header
        let wrapped = CryptoService.wrapVaultData(ciphertext: ciphertext, keyData: key)

        // Unwrap HMAC header
        let unwrappedCipher = try CryptoService.unwrapVaultData(wrapped, keyData: key)

        // Decrypt
        let decrypted = try CryptoService.decrypt(data: unwrappedCipher, with: key)

        // Decode
        let decoded = try JSONDecoder().decode(VaultDatabase.self, from: decrypted)

        XCTAssertEqual(decoded.entries.count, 1)
        XCTAssertEqual(decoded.entries.first?.title, "GitHub")
        XCTAssertEqual(decoded.entries.first?.username, "user@example.com")
        XCTAssertEqual(decoded.entries.first?.password, "SuperSecure!123")
    }
}

// Make SecurityError Equatable for test assertions
extension SecurityError: Equatable {
    public static func == (lhs: SecurityError, rhs: SecurityError) -> Bool {
        switch (lhs, rhs) {
        case (.accountNotFound, .accountNotFound): return true
        case (.encryptionFailure, .encryptionFailure): return true
        case (.decryptionFailure, .decryptionFailure): return true
        case (.tampered, .tampered): return true
        case (.weakPassword(let a), .weakPassword(let b)): return a == b
        default: return false
        }
    }
}
