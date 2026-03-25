import Foundation
import CryptoKit
import CommonCrypto

// MARK: - Crypto Service

enum CryptoService {
    static let defaultMasterRounds = 210_000
    /// Magic bytes prepended to the vault file for quick format identification
    private static let vaultMagic: [UInt8] = [0x46, 0x59, 0x58, 0x56] // "FYXV"

    // MARK: Master Password Hashing

    static func hashMasterPasswordPBKDF2(_ password: String, salt: Data, rounds: Int = defaultMasterRounds) -> String {
        let key = pbkdf2SHA256(password: Data(password.utf8), salt: salt, rounds: rounds, keyLength: 32)
        return key.map { String(format: "%02x", $0) }.joined()
    }

    static func verifyMasterPassword(_ password: String, account: Account) -> Bool {
        if account.passwordHashAlgorithm == "pbkdf2-sha256" {
            let rounds = max(account.passwordHashRounds, 100_000)
            return hashMasterPasswordPBKDF2(password, salt: account.passwordSalt, rounds: rounds) == account.passwordHash
        }
        return hashPasswordLegacy(password, salt: account.passwordSalt) == account.passwordHash
    }

    static func masterRounds() -> Int { defaultMasterRounds }

    private static func hashPasswordLegacy(_ password: String, salt: Data) -> String {
        var payload = Data()
        payload.append(salt)
        payload.append(Data(password.utf8))
        return SHA256.hash(data: payload).compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: Key Material

    static func makeSalt() -> Data {
        Data((0..<16).map { _ in UInt8.random(in: 0...255) })
    }

    static func deriveBackupKey(passphrase: String, salt: Data) -> Data {
        pbkdf2SHA256(password: Data(passphrase.utf8), salt: salt, rounds: 120_000, keyLength: 32)
    }

    static func hmacSHA256(data: Data, key: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key)))
    }

    static func symmetricKeyData() throws -> Data {
        if let existing = KeychainService.loadOptionalData(for: SecureStoreKey.vaultSymmetricKey) {
            return existing
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        try KeychainService.save(data: keyData, key: SecureStoreKey.vaultSymmetricKey)
        return keyData
    }

    static func replaceSymmetricKeyData(with data: Data) throws {
        try KeychainService.save(data: data, key: SecureStoreKey.vaultSymmetricKey)
    }

    // MARK: Encryption / Decryption

    static func encrypt(data: Data, with keyData: Data) throws -> Data {
        let key = SymmetricKey(data: keyData)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw SecurityError.encryptionFailure
        }
        return combined
    }

    static func decrypt(data: Data, with keyData: Data) throws -> Data {
        let key = SymmetricKey(data: keyData)
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    // MARK: Vault File Format (HMAC-wrapped)
    //
    // Layout: [4 magic][32 HMAC-SHA256][N AES-GCM ciphertext]
    //
    // The HMAC provides a fast integrity check without full decryption.
    // AES-GCM itself already authenticates; HMAC adds defense-in-depth.

    static func wrapVaultData(ciphertext: Data, keyData: Data) -> Data {
        let hmac = hmacSHA256(data: ciphertext, key: keyData)
        var result = Data(vaultMagic)
        result.append(hmac)
        result.append(ciphertext)
        return result
    }

    static func unwrapVaultData(_ raw: Data, keyData: Data) throws -> Data {
        let magicCount = vaultMagic.count
        let hmacCount = 32
        let headerSize = magicCount + hmacCount

        guard raw.count > headerSize else { throw SecurityError.tampered }

        let magic = Array(raw.prefix(magicCount))
        guard magic == vaultMagic else { throw SecurityError.tampered }

        let storedHMAC = raw.dropFirst(magicCount).prefix(hmacCount)
        let ciphertext = raw.dropFirst(headerSize)

        let expectedHMAC = hmacSHA256(data: ciphertext, key: keyData)
        guard storedHMAC == expectedHMAC else { throw SecurityError.tampered }

        return Data(ciphertext)
    }

    // MARK: Recovery Key

    /// Generates a 32-character uppercase alphanumeric recovery key.
    /// Displayed as 8 groups of 4 characters: XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX
    static func generateRecoveryKey() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return (0..<32).map { _ in String(chars.randomElement()!) }.joined()
    }

    static func formatRecoveryKey(_ raw: String) -> String {
        stride(from: 0, to: raw.count, by: 4).map { i in
            let start = raw.index(raw.startIndex, offsetBy: i)
            let end = raw.index(start, offsetBy: min(4, raw.count - i))
            return String(raw[start..<end])
        }.joined(separator: "-")
    }

    static func hashRecoveryKey(_ key: String, salt: Data) -> String {
        // Normalise: remove dashes, uppercase
        let clean = key.replacingOccurrences(of: "-", with: "").uppercased()
        return hashMasterPasswordPBKDF2(clean, salt: salt, rounds: 100_000)
    }

    static func verifyRecoveryKey(_ key: String, account: Account) -> Bool {
        guard let hash = account.recoveryKeyHash,
              let salt = account.recoveryKeySalt else { return false }
        let clean = key.replacingOccurrences(of: "-", with: "").uppercased()
        return hashRecoveryKey(clean, salt: salt) == hash
    }

    // MARK: PBKDF2

    static func pbkdf2SHA256(password: Data, salt: Data, rounds: Int, keyLength: Int) -> Data {
        var derived = Data(repeating: 0, count: keyLength)
        let rounds32 = UInt32(max(rounds, 1))
        _ = derived.withUnsafeMutableBytes { derivedBytes in
            password.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        password.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        rounds32,
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        keyLength
                    )
                }
            }
        }
        return derived
    }
}
