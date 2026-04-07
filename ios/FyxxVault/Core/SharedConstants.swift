import Foundation

/// Constants shared between the main app and extensions (AutoFill, etc.)
enum FyxxVaultConstants {
    /// App Group identifier — must match the entitlement in both targets
    static let appGroupID = "group.com.fyxx.fyxxvault"

    /// Shared container URL for vault data (accessible by app + extensions)
    static var sharedContainerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    /// Directory inside the shared container for vault files
    static var sharedVaultDirectoryURL: URL {
        let url = sharedContainerURL.appendingPathComponent("FyxxVaultData", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Encrypted vault file path
    static var vaultFileURL: URL {
        sharedVaultDirectoryURL.appendingPathComponent("vault.enc")
    }

    /// Snapshots directory
    static var snapshotsDirectoryURL: URL {
        let url = sharedVaultDirectoryURL.appendingPathComponent("Snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Keychain access group — uses the App Group ID for sharing with extensions
    static let keychainAccessGroup = appGroupID
}
