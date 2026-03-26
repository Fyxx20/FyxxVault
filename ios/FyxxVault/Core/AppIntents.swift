import AppIntents
import SwiftUI

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
        await MainActor.run {
            UIPasteboard.general.string = password
        }
        #endif

        return .result(dialog: "Generated: \(password)\n\nCopied to clipboard!")
    }
}

// MARK: - Open Vault Intent

struct OpenVaultIntent: AppIntent {
    static var title: LocalizedStringResource = "Open FyxxVault"
    static var description = IntentDescription("Open the FyxxVault password manager")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct FyxxVaultShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
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
            intent: OpenVaultIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Ouvre \(.applicationName)"
            ],
            shortTitle: "Open Vault",
            systemImageName: "lock.shield"
        )
    }
}
