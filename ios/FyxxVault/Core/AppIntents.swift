import AppIntents
import SwiftUI

// MARK: - Copy Password Intent

struct CopyPasswordIntent: AppIntent {
    static var title: LocalizedStringResource = "Copy Password"
    static var description = IntentDescription("Copy a password from FyxxVault to clipboard")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Account Name")
    var accountName: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Load vault entries from shared container
        guard let entries = loadVaultEntries() else {
            return .result(dialog: "Unable to access vault. Please unlock FyxxVault first.")
        }

        // Find matching entry
        guard let entry = entries.first(where: {
            $0.title.localizedCaseInsensitiveContains(accountName)
        }) else {
            return .result(dialog: "No account found matching '\(accountName)'")
        }

        // Copy to clipboard
        #if canImport(UIKit)
        UIPasteboard.general.string = entry.password
        #endif

        // Auto-clear after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            #if canImport(UIKit)
            if UIPasteboard.general.string == entry.password {
                UIPasteboard.general.string = ""
            }
            #endif
        }

        return .result(dialog: "Password for \(entry.title) copied! Clipboard clears in 30s.")
    }

    private func loadVaultEntries() -> [SimpleEntry]? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.fyxx.fyxxvault"
        ) else { return nil }

        let fileURL = containerURL
            .appendingPathComponent("FyxxVaultData", isDirectory: true)
            .appendingPathComponent("vault.enc")

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        // Note: actual decryption requires the symmetric key from Keychain
        // This is a simplified version - full implementation needs shared Keychain access
        return nil
    }
}

struct SimpleEntry: Codable {
    var title: String
    var username: String
    var password: String
    var website: String
}

// MARK: - Search Vault Intent

struct SearchVaultIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Vault"
    static var description = IntentDescription("Search for an account in FyxxVault")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Search Query")
    var query: String

    func perform() async throws -> some IntentResult {
        // Opens the app - the app will handle the deep link
        return .result()
    }
}

// MARK: - Generate Password Intent

struct GeneratePasswordIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate Password"
    static var description = IntentDescription("Generate a secure random password")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Length", default: 18)
    var length: Int

    @Parameter(title: "Include Symbols", default: true)
    var includeSymbols: Bool

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let chars = "abcdefghijklmnopqrstuvwxyz"
        let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let digits = "0123456789"
        let symbols = "!@#$%^&*()-_=+"

        var pool = chars + upper + digits
        if includeSymbols { pool += symbols }

        let password = String((0..<max(8, min(length, 64))).map { _ in
            pool.randomElement()!
        })

        #if canImport(UIKit)
        UIPasteboard.general.string = password
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            #if canImport(UIKit)
            if UIPasteboard.general.string == password {
                UIPasteboard.general.string = ""
            }
            #endif
        }

        return .result(dialog: "Generated: \(password)\n\nCopied to clipboard! Clears in 30s.")
    }
}

// MARK: - App Shortcuts Provider

struct FyxxVaultShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CopyPasswordIntent(),
            phrases: [
                "Copy my \(\.$accountName) password in \(.applicationName)",
                "Get \(\.$accountName) password from \(.applicationName)",
                "Copie mon mot de passe \(\.$accountName) dans \(.applicationName)"
            ],
            shortTitle: "Copy Password",
            systemImageName: "doc.on.doc"
        )
        AppShortcut(
            intent: GeneratePasswordIntent(),
            phrases: [
                "Generate a password with \(.applicationName)",
                "Create a new password in \(.applicationName)",
                "Génère un mot de passe avec \(.applicationName)"
            ],
            shortTitle: "Generate Password",
            systemImageName: "key.fill"
        )
        AppShortcut(
            intent: SearchVaultIntent(),
            phrases: [
                "Search \(\.$query) in \(.applicationName)",
                "Find \(\.$query) in \(.applicationName)",
                "Cherche \(\.$query) dans \(.applicationName)"
            ],
            shortTitle: "Search Vault",
            systemImageName: "magnifyingglass"
        )
    }
}
