import Foundation
import SwiftUI
import Combine

// MARK: - Breach Monitor Service (Dark Web Monitoring via HIBP)

@MainActor
final class BreachMonitorService: ObservableObject {
    @Published var breachedEntries: [UUID: Int] = [:]  // entryID → breach count
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var lastScanDate: Date?

    private let scanIntervalHours: Double = 24
    private let requestDelay: UInt64 = 1_500_000_000  // 1.5s in nanoseconds
    private static let lastScanKey = "fyxxvault.breach.last.scan"

    init() {
        lastScanDate = UserDefaults.standard.object(forKey: Self.lastScanKey) as? Date
    }

    /// Number of entries whose password appeared in at least one breach
    var totalBreached: Int { breachedEntries.values.filter { $0 > 0 }.count }

    /// True if 24 hours have passed since the last scan (or no scan was ever done)
    func shouldAutoScan() -> Bool {
        guard let last = lastScanDate else { return true }
        return Date().timeIntervalSince(last) > scanIntervalHours * 3600
    }

    /// Scan every vault entry against HIBP, rate-limited to 1 request per 1.5 s.
    func scanAll(entries: [VaultEntry]) async {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0
        breachedEntries = [:]

        let total = entries.count
        for (index, entry) in entries.enumerated() {
            guard !entry.password.isEmpty else {
                scanProgress = Double(index + 1) / Double(max(total, 1))
                continue
            }

            let count = await PasswordBreachService.compromisedCount(password: entry.password)
            if let count, count > 0 {
                breachedEntries[entry.id] = count
            }

            scanProgress = Double(index + 1) / Double(max(total, 1))

            // Rate limit: wait 1.5 s between requests (skip after last entry)
            if index < total - 1 {
                try? await Task.sleep(nanoseconds: requestDelay)
            }
        }

        lastScanDate = Date()
        UserDefaults.standard.set(lastScanDate, forKey: Self.lastScanKey)
        isScanning = false
    }

    /// Check a single entry against HIBP (no rate-limit guard — caller decides).
    func scanSingle(entry: VaultEntry) async {
        guard !entry.password.isEmpty else { return }
        let count = await PasswordBreachService.compromisedCount(password: entry.password)
        if let count {
            breachedEntries[entry.id] = count
        }
    }

    /// Convenience accessor
    func breachCount(for entryID: UUID) -> Int? {
        breachedEntries[entryID]
    }
}
