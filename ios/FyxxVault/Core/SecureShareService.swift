import Foundation
import CryptoKit

struct SecureShareLink: Codable {
    let id: String
    let encryptedPayload: Data  // AES-256-GCM encrypted entry JSON
    let expiresAt: Date
    let maxViews: Int
    var viewCount: Int

    var isExpired: Bool {
        Date() >= expiresAt || viewCount >= maxViews
    }
}

struct SharePayload: Codable {
    var title: String
    var username: String
    var password: String
    var website: String
    var notes: String
}

enum SecureShareService {

    /// Create a shareable encrypted link for a vault entry
    /// Returns (shareURL, decryptionKey) - both needed to access the shared data
    static func createShareLink(
        entry: VaultEntry,
        expiresIn: TimeInterval = 3600, // 1 hour default
        maxViews: Int = 1
    ) -> (shareData: String, key: String)? {
        let payload = SharePayload(
            title: entry.title,
            username: entry.username,
            password: entry.password,
            website: entry.website,
            notes: entry.notes
        )

        guard let payloadData = try? JSONEncoder().encode(payload) else { return nil }

        // Generate random encryption key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        // Encrypt payload
        guard let sealedBox = try? AES.GCM.seal(payloadData, using: key) else { return nil }
        guard let combined = sealedBox.combined else { return nil }

        // Create share data (base64 encoded encrypted payload)
        let shareData = combined.base64EncodedString()
        let keyString = keyData.base64EncodedString()

        return (shareData: shareData, key: keyString)
    }

    /// Decrypt a shared entry using the key
    static func decryptShare(shareData: String, key: String) -> SharePayload? {
        guard let encryptedData = Data(base64Encoded: shareData),
              let keyData = Data(base64Encoded: key) else { return nil }

        let symmetricKey = SymmetricKey(data: keyData)

        guard let sealedBox = try? AES.GCM.SealedBox(combined: encryptedData),
              let decryptedData = try? AES.GCM.open(sealedBox, using: symmetricKey),
              let payload = try? JSONDecoder().decode(SharePayload.self, from: decryptedData) else {
            return nil
        }

        return payload
    }
}
