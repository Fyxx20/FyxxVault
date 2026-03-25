import Foundation
import Security

// MARK: - Keychain Service

enum KeychainService {
    static let service = "FyxxVault.security"

    // MARK: Data

    static func save(data: Data, key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecurityError.encryptionFailure
        }
    }

    static func loadData(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw SecurityError.accountNotFound
        }
        return data
    }

    static func loadOptionalData(for key: String) -> Data? {
        try? loadData(for: key)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: Int helpers (for persistent failed attempt counter)

    static func saveInt(_ value: Int, key: String) throws {
        var v = value
        let data = Data(bytes: &v, count: MemoryLayout<Int>.size)
        try save(data: data, key: key)
    }

    static func loadInt(for key: String) -> Int {
        guard let data = loadOptionalData(for: key),
              data.count == MemoryLayout<Int>.size else { return 0 }
        return data.withUnsafeBytes { $0.load(as: Int.self) }
    }

    // MARK: Date helpers (for lockout timestamp)

    static func saveDate(_ date: Date, key: String) throws {
        var ts = date.timeIntervalSince1970
        let data = Data(bytes: &ts, count: MemoryLayout<Double>.size)
        try save(data: data, key: key)
    }

    static func loadDate(for key: String) -> Date? {
        guard let data = loadOptionalData(for: key),
              data.count == MemoryLayout<Double>.size else { return nil }
        let ts = data.withUnsafeBytes { $0.load(as: Double.self) }
        return Date(timeIntervalSince1970: ts)
    }
}
