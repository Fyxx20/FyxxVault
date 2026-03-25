import XCTest
import CryptoKit
@testable import FyxxVault

final class CryptoServiceTests: XCTestCase {

    // MARK: - AES-256-GCM Encrypt / Decrypt

    func testEncryptDecryptRoundTrip() throws {
        let plaintext = Data("FyxxVault secret payload".utf8)
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let ciphertext = try CryptoService.encrypt(data: plaintext, with: key)
        let decrypted = try CryptoService.decrypt(data: ciphertext, with: key)

        XCTAssertEqual(decrypted, plaintext, "Decrypted data must match original plaintext")
    }

    func testEncryptProducesDifferentCiphertextEachTime() throws {
        let plaintext = Data("same input".utf8)
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let a = try CryptoService.encrypt(data: plaintext, with: key)
        let b = try CryptoService.encrypt(data: plaintext, with: key)

        XCTAssertNotEqual(a, b, "AES-GCM random nonce must produce different ciphertexts")
    }

    func testDecryptWithWrongKeyFails() throws {
        let plaintext = Data("secret".utf8)
        let keyA = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let keyB = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let ciphertext = try CryptoService.encrypt(data: plaintext, with: keyA)

        XCTAssertThrowsError(try CryptoService.decrypt(data: ciphertext, with: keyB),
                             "Decrypting with a different key must throw")
    }

    func testEncryptDecryptEmptyData() throws {
        let plaintext = Data()
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let encrypted = try CryptoService.encrypt(data: plaintext, with: key)
        let decrypted = try CryptoService.decrypt(data: encrypted, with: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptDecryptLargePayload() throws {
        let plaintext = Data((0..<1_000_000).map { _ in UInt8.random(in: 0...255) })
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let encrypted = try CryptoService.encrypt(data: plaintext, with: key)
        let decrypted = try CryptoService.decrypt(data: encrypted, with: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    // MARK: - HMAC-SHA256

    func testHMACConsistency() {
        let data = Data("consistent input".utf8)
        let key = Data("test key 32 bytes long padding!!".utf8)

        let hmac1 = CryptoService.hmacSHA256(data: data, key: key)
        let hmac2 = CryptoService.hmacSHA256(data: data, key: key)

        XCTAssertEqual(hmac1, hmac2, "Same input and key must produce identical HMAC")
        XCTAssertEqual(hmac1.count, 32, "SHA-256 HMAC must be 32 bytes")
    }

    func testHMACDifferentData() {
        let key = Data("hmac-key-material-32-bytes!!!!!".utf8)
        let hmacA = CryptoService.hmacSHA256(data: Data("alpha".utf8), key: key)
        let hmacB = CryptoService.hmacSHA256(data: Data("bravo".utf8), key: key)

        XCTAssertNotEqual(hmacA, hmacB, "Different inputs must produce different HMACs")
    }

    func testHMACDifferentKeys() {
        let data = Data("test data".utf8)
        let key1 = Data("key one 32 bytes long padding!!!".utf8)
        let key2 = Data("key two 32 bytes long padding!!!".utf8)

        let hmac1 = CryptoService.hmacSHA256(data: data, key: key1)
        let hmac2 = CryptoService.hmacSHA256(data: data, key: key2)

        XCTAssertNotEqual(hmac1, hmac2, "Different keys must produce different HMACs")
    }

    // MARK: - Vault File Format (FYXV header + HMAC)

    func testVaultWrapUnwrap() throws {
        let ciphertext = Data("some-aes-gcm-ciphertext-blob".utf8)
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let wrapped = CryptoService.wrapVaultData(ciphertext: ciphertext, keyData: key)
        let unwrapped = try CryptoService.unwrapVaultData(wrapped, keyData: key)

        XCTAssertEqual(unwrapped, ciphertext, "Unwrapped ciphertext must match original")
    }

    func testVaultUnwrapTamperedFails() {
        let ciphertext = Data("payload".utf8)
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        var wrapped = CryptoService.wrapVaultData(ciphertext: ciphertext, keyData: key)

        // Tamper with the HMAC region (bytes 4..<36)
        wrapped[5] ^= 0xFF

        XCTAssertThrowsError(try CryptoService.unwrapVaultData(wrapped, keyData: key)) { error in
            XCTAssertEqual(error as? SecurityError, .tampered, "Tampered HMAC must throw .tampered")
        }
    }

    func testVaultUnwrapTamperedCiphertextFails() {
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

    func testVaultMagicBytes() {
        let ciphertext = Data("test".utf8)
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let wrapped = CryptoService.wrapVaultData(ciphertext: ciphertext, keyData: key)

        XCTAssertEqual(wrapped[0], 0x46, "First magic byte must be 'F' (0x46)")
        XCTAssertEqual(wrapped[1], 0x59, "Second magic byte must be 'Y' (0x59)")
        XCTAssertEqual(wrapped[2], 0x58, "Third magic byte must be 'X' (0x58)")
        XCTAssertEqual(wrapped[3], 0x56, "Fourth magic byte must be 'V' (0x56)")
    }

    func testUnwrapWithWrongKeyThrows() {
        let ciphertext = Data("encrypted vault data".utf8)
        let correctKey = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let wrongKey = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let wrapped = CryptoService.wrapVaultData(ciphertext: ciphertext, keyData: correctKey)

        XCTAssertThrowsError(try CryptoService.unwrapVaultData(wrapped, keyData: wrongKey))
    }

    func testUnwrapTooShortDataThrows() {
        let shortData = Data([0x46, 0x59, 0x58, 0x56]) // Just magic, no HMAC or ciphertext
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        XCTAssertThrowsError(try CryptoService.unwrapVaultData(shortData, keyData: key))
    }

    // MARK: - PBKDF2-SHA256

    func testPBKDF2Deterministic() {
        let password = Data("MyMasterPassword!".utf8)
        let salt = Data("fixed_salt_16byt".utf8)
        let rounds = 1_000

        let hash1 = CryptoService.pbkdf2SHA256(password: password, salt: salt, rounds: rounds, keyLength: 32)
        let hash2 = CryptoService.pbkdf2SHA256(password: password, salt: salt, rounds: rounds, keyLength: 32)

        XCTAssertEqual(hash1, hash2, "Same password, salt, and rounds must produce identical output")
        XCTAssertEqual(hash1.count, 32)
    }

    func testPBKDF2DifferentSalts() {
        let password = Data("MyPassword".utf8)
        let saltA = Data("salt_one_16bytes".utf8)
        let saltB = Data("salt_two_16bytes".utf8)

        let hashA = CryptoService.pbkdf2SHA256(password: password, salt: saltA, rounds: 1_000, keyLength: 32)
        let hashB = CryptoService.pbkdf2SHA256(password: password, salt: saltB, rounds: 1_000, keyLength: 32)

        XCTAssertNotEqual(hashA, hashB, "Different salts must produce different hashes")
    }

    func testPBKDF2DifferentPasswords() {
        let salt = Data("fixed_salt_16byt".utf8)

        let key1 = CryptoService.pbkdf2SHA256(password: Data("password1".utf8), salt: salt, rounds: 1_000, keyLength: 32)
        let key2 = CryptoService.pbkdf2SHA256(password: Data("password2".utf8), salt: salt, rounds: 1_000, keyLength: 32)

        XCTAssertNotEqual(key1, key2, "Different passwords must produce different keys")
    }

    // MARK: - Salt Generation

    func testMakeSaltRandomness() {
        let salt1 = CryptoService.makeSalt()
        let salt2 = CryptoService.makeSalt()

        XCTAssertEqual(salt1.count, 16, "Salt must be 16 bytes")
        XCTAssertEqual(salt2.count, 16, "Salt must be 16 bytes")
        XCTAssertNotEqual(salt1, salt2, "Two salts must differ (probabilistically)")
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

    // MARK: - Recovery Key

    func testRecoveryKeyGeneration() {
        let key = CryptoService.generateRecoveryKey()
        XCTAssertEqual(key.count, 32, "Recovery key must be 32 characters")

        let allowedSet = CharacterSet(charactersIn: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        for char in key.unicodeScalars {
            XCTAssertTrue(allowedSet.contains(char),
                          "Character '\(char)' must be in the allowed set (no I, O, L, 0, 1)")
        }
    }

    func testRecoveryKeyFormatting() {
        let raw = CryptoService.generateRecoveryKey()
        let formatted = CryptoService.formatRecoveryKey(raw)

        let groups = formatted.split(separator: "-")
        XCTAssertEqual(groups.count, 8, "Formatted key must have 8 groups (32 / 4)")
        for group in groups {
            XCTAssertEqual(group.count, 4, "Each group must be 4 characters")
        }
    }

    func testRecoveryKeyHashVerify() {
        let key = CryptoService.generateRecoveryKey()
        let salt = CryptoService.makeSalt()

        let hash = CryptoService.hashRecoveryKey(key, salt: salt)
        let hashAgain = CryptoService.hashRecoveryKey(key, salt: salt)

        XCTAssertEqual(hash, hashAgain, "Hashing the same key and salt must be deterministic")
        XCTAssertFalse(hash.isEmpty, "Hash must not be empty")
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

        XCTAssertTrue(CryptoService.verifyRecoveryKey(formatted, account: account),
                      "Formatted (dashed) key must verify successfully")
    }

    // MARK: - Symmetric Key Size

    func testSymmetricKeySize() {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        XCTAssertEqual(keyData.count, 32, "256-bit key must be 32 bytes")
    }

    // MARK: - Full End-to-End Vault Round Trip

    func testFullVaultRoundTrip() throws {
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }

        let entry = VaultEntry(
            title: "GitHub",
            username: "user@example.com",
            password: "SuperSecure!123",
            website: "https://github.com",
            notes: "My dev account"
        )
        let db = VaultDatabase(entries: [entry], trash: [], activityLog: [])
        let payload = try JSONEncoder().encode(db)

        let ciphertext = try CryptoService.encrypt(data: payload, with: key)
        let wrapped = CryptoService.wrapVaultData(ciphertext: ciphertext, keyData: key)
        let unwrappedCipher = try CryptoService.unwrapVaultData(wrapped, keyData: key)
        let decrypted = try CryptoService.decrypt(data: unwrappedCipher, with: key)
        let decoded = try JSONDecoder().decode(VaultDatabase.self, from: decrypted)

        XCTAssertEqual(decoded.entries.count, 1)
        XCTAssertEqual(decoded.entries.first?.title, "GitHub")
        XCTAssertEqual(decoded.entries.first?.username, "user@example.com")
        XCTAssertEqual(decoded.entries.first?.password, "SuperSecure!123")
    }
}

// MARK: - SecurityError Equatable conformance for test assertions

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
