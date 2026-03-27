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
    /// Dates are encoded as ISO 8601 strings to stay compatible with the web app.
    static func encryptEntry(_ entry: VaultEntry, with vek: Data) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(entry)
        return try CryptoService.encrypt(data: json, with: vek)
    }

    /// Decrypt a single VaultEntry from cloud storage.
    /// Handles both ISO 8601 strings (from web) and legacy Double timestamps (from older iOS builds).
    static func decryptEntry(_ blob: Data, with vek: Data) throws -> VaultEntry {
        let json = try CryptoService.decrypt(data: blob, with: vek)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            // Try ISO 8601 string first (web format)
            if let str = try? container.decode(String.self) {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = iso.date(from: str) { return d }
                // Without fractional seconds
                iso.formatOptions = [.withInternetDateTime]
                if let d = iso.date(from: str) { return d }
                // Fallback: try basic ISO
                if let d = ISO8601DateFormatter().date(from: str) { return d }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot parse date: \(str)")
            }
            // Legacy: Double (seconds from Swift reference date Jan 1 2001)
            let secs = try container.decode(Double.self)
            return Date(timeIntervalSinceReferenceDate: secs)
        }
        return try decoder.decode(VaultEntry.self, from: json)
    }
}
