import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Widget Data Types (shared between app and widget extension)

struct VaultWidgetEntry: Codable {
    var totalAccounts: Int
    var securityScore: Int
    var weakCount: Int
    var breachedCount: Int
    var reusedCount: Int
    var lastSyncDate: Date?
}

/// Updates the shared widget data that the widget extension reads
enum WidgetDataProvider {
    private static let suiteName = "group.com.fyxx.fyxxvault"
    private static let key = "fyxxvault.widget.data"

    static func updateWidgetData(
        totalAccounts: Int,
        securityScore: Int,
        weakCount: Int,
        breachedCount: Int,
        reusedCount: Int,
        lastSyncDate: Date?
    ) {
        let entry = VaultWidgetEntry(
            totalAccounts: totalAccounts,
            securityScore: securityScore,
            weakCount: weakCount,
            breachedCount: breachedCount,
            reusedCount: reusedCount,
            lastSyncDate: lastSyncDate
        )

        guard let data = try? JSONEncoder().encode(entry) else { return }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: key)

        // Reload widget timelines
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func loadWidgetData() -> VaultWidgetEntry {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key),
              let entry = try? JSONDecoder().decode(VaultWidgetEntry.self, from: data) else {
            return VaultWidgetEntry(
                totalAccounts: 0,
                securityScore: 0,
                weakCount: 0,
                breachedCount: 0,
                reusedCount: 0,
                lastSyncDate: nil
            )
        }
        return entry
    }
}
