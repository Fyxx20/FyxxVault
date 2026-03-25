import Foundation
import CryptoKit

/// Minimal crypto operations shared between the main app and the AutoFill extension.
/// This avoids pulling in the full CryptoService (which has PBKDF2 / recovery key logic).
enum SharedCrypto {
    private static let vaultMagic: [UInt8] = [0x46, 0x59, 0x58, 0x56] // "FYXV"

    /// Decrypt AES-256-GCM sealed data.
    static func decrypt(data: Data, with keyData: Data) throws -> Data {
        let key = SymmetricKey(data: keyData)
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    /// Unwrap the vault file format: [4-byte magic][32-byte HMAC][ciphertext]
    static func unwrapVaultData(_ raw: Data, keyData: Data) throws -> Data {
        let magicCount = vaultMagic.count
        let hmacCount = 32
        let headerSize = magicCount + hmacCount

        guard raw.count > headerSize else { throw SharedCryptoError.tampered }

        let magic = Array(raw.prefix(magicCount))
        guard magic == vaultMagic else { throw SharedCryptoError.tampered }

        let storedHMAC = raw.dropFirst(magicCount).prefix(hmacCount)
        let ciphertext = raw.dropFirst(headerSize)

        let expectedHMAC = Data(HMAC<SHA256>.authenticationCode(
            for: ciphertext,
            using: SymmetricKey(data: keyData)
        ))
        guard storedHMAC == expectedHMAC else { throw SharedCryptoError.tampered }

        return Data(ciphertext)
    }

    enum SharedCryptoError: Error {
        case tampered
        case decryptionFailed
    }
}
