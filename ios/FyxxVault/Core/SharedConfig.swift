import Foundation

/// Constants shared between the main app and extensions.
enum SharedConfig {
    /// App Group identifier for sharing data between the main app and AutoFill extension.
    static let appGroupIdentifier = "group.com.fyxx.fyxxvault"

    /// Keychain access group for sharing secrets between the main app and extensions.
    static let keychainAccessGroup = "com.fyxx.fyxxvault.shared"

    /// Keychain account name for the vault symmetric key.
    static let vaultSymmetricKeyAccount = "fyxxvault.vault.symmetric.key"

    /// Vault data directory name inside the shared container.
    static let vaultDataDirectory = "FyxxVaultData"

    /// Vault encrypted file name.
    static let vaultFileName = "vault.enc"

    /// Returns the URL for the shared App Group container's vault file.
    static var sharedVaultFileURL: URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return nil }

        let folder = containerURL.appendingPathComponent(vaultDataDirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(vaultFileName)
    }

    /// Returns the URL for the shared snapshots directory.
    static var sharedSnapshotsURL: URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return nil }

        let folder = containerURL
            .appendingPathComponent(vaultDataDirectory, isDirectory: true)
            .appendingPathComponent("Snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
