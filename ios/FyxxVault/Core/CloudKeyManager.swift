import Foundation
import CryptoKit

/// Zero-knowledge key management for cloud sync.
/// The master password never leaves the device.
/// VEK (Vault Encryption Key) is wrapped with KEK (Key Encryption Key) derived from master password.
enum CloudKeyManager {

    /// Derive a Key Encryption Key (KEK) from the master password.
    /// Used to wrap/unwrap the VEK.
    static func deriveKEK(masterPassword: String, salt: Data, rounds: Int = 210_000) -> Data {
        CryptoService.pbkdf2SHA256(
            password: Data(masterPassword.utf8),
            salt: salt,
            rounds: rounds,
            keyLength: 32
        )
    }

    /// Generate a random 256-bit Vault Encryption Key.
    static func generateVEK() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        return Data(bytes)
    }

    /// Wrap (encrypt) the VEK with the KEK using AES-256-GCM.
    static func wrapVEK(_ vek: Data, with kek: Data) throws -> Data {
        try CryptoService.encrypt(data: vek, with: kek)
    }

    /// Unwrap (decrypt) the VEK using the KEK.
    static func unwrapVEK(_ wrappedVEK: Data, with kek: Data) throws -> Data {
        try CryptoService.decrypt(data: wrappedVEK, with: kek)
    }

    /// Encrypt a single VaultEntry for cloud storage.
    static func encryptEntry(_ entry: VaultEntry, with vek: Data) throws -> Data {
        let json = try JSONEncoder().encode(entry)
        return try CryptoService.encrypt(data: json, with: vek)
    }

    /// Decrypt a single VaultEntry from cloud storage.
    static func decryptEntry(_ blob: Data, with vek: Data) throws -> VaultEntry {
        let json = try CryptoService.decrypt(data: blob, with: vek)
        return try JSONDecoder().decode(VaultEntry.self, from: json)
    }
}
