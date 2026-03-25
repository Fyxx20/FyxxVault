import SwiftUI
import Foundation
import UniformTypeIdentifiers
import Combine
import CryptoKit

@MainActor
final class VaultStore: ObservableObject {
    @Published private(set) var entries: [VaultEntry] = []
    @Published private(set) var trashEntries: [VaultTrashItem] = []
    @Published private(set) var activityLog: [ActivityLogItem] = []
    @Published var integrityWarning = ""
    /// Non-empty when a persistence write fails — shown to the user
    @Published var persistenceError = ""

    private let fileURL: URL
    private let snapshotsDirectoryURL: URL
    private var keyData: Data?
    private let trashRetentionDays = 30
    private let snapshotRetentionCount = 30

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = appSupport.appendingPathComponent("FyxxVaultData", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = folder.appendingPathComponent("vault.enc")
        self.snapshotsDirectoryURL = folder.appendingPathComponent("Snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: snapshotsDirectoryURL, withIntermediateDirectories: true)
        self.keyData = try? CryptoService.symmetricKeyData()

        loadEntries()
        purgeExpiredTrash()
        rotateVaultKeyIfNeeded()
        maybeCreateDailySnapshot()
    }

    // MARK: CRUD

    func addEntry(_ entry: VaultEntry) {
        entries.insert(entry, at: 0)
        log("Création", target: entry.title)
        persistEntries()
    }

    func updateEntry(_ entry: VaultEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        var updated = entry
        updated.lastModifiedAt = Date()
        let current = entries[index]
        if current.password != updated.password {
            var history = current.passwordHistory
            history.insert(PasswordVersion(password: updated.password), at: 0)
            updated.passwordHistory = Array(history.prefix(20))
            updated.passwordLastChangedAt = Date()
        } else {
            updated.passwordHistory = current.passwordHistory
        }
        entries[index] = updated
        log("Édition", target: updated.title)
        persistEntries()
    }

    func deleteEntries(at offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            entries.indices.contains(index) ? entries[index].id : nil
        }
        for id in ids { moveToTrash(entryID: id) }
    }

    @discardableResult
    func moveToTrash(entryID: UUID) -> UUID? {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return nil }
        let entry = entries.remove(at: index)
        let deletedAt = Date()
        let expiresAt = Calendar.current.date(byAdding: .day, value: trashRetentionDays, to: deletedAt) ?? deletedAt
        let trashItem = VaultTrashItem(id: UUID(), entry: entry, deletedAt: deletedAt, expiresAt: expiresAt)
        trashEntries.insert(trashItem, at: 0)
        log("Corbeille", target: entry.title)
        persistEntries()
        return trashItem.id
    }

    func bulkMoveToTrash(entryIDs: Set<UUID>) {
        for id in entryIDs { moveToTrash(entryID: id) }
    }

    func bulkSetFavorite(entryIDs: Set<UUID>, value: Bool) {
        var changed = false
        for index in entries.indices {
            if entryIDs.contains(entries[index].id) {
                entries[index].isFavorite = value
                changed = true
            }
        }
        if changed { log("Bulk favori", target: "\(entryIDs.count) entrée(s)"); persistEntries() }
    }

    func bulkApplyTag(entryIDs: Set<UUID>, tag: String) {
        let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var changed = false
        for index in entries.indices {
            if entryIDs.contains(entries[index].id), !entries[index].tags.contains(clean) {
                entries[index].tags.append(clean)
                changed = true
            }
        }
        if changed { log("Bulk tag", target: clean); persistEntries() }
    }

    func bulkMoveToFolder(entryIDs: Set<UUID>, folder: String) {
        let clean = folder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var changed = false
        for index in entries.indices {
            if entryIDs.contains(entries[index].id) {
                entries[index].folder = clean
                changed = true
            }
        }
        if changed { log("Bulk déplacement", target: clean); persistEntries() }
    }

    func reorderEntries(from source: IndexSet, to destination: Int) {
        entries.move(fromOffsets: source, toOffset: destination)
        log("Réorganisation", target: "Ordre des entrées")
        persistEntries()
    }

    // MARK: Trash

    func restoreFromTrash(_ trashID: UUID) {
        guard let index = trashEntries.firstIndex(where: { $0.id == trashID }) else { return }
        let item = trashEntries.remove(at: index)
        entries.insert(item.entry, at: 0)
        log("Restauration", target: item.entry.title)
        persistEntries()
    }

    func permanentlyDeleteFromTrash(_ trashID: UUID) {
        guard let index = trashEntries.firstIndex(where: { $0.id == trashID }) else { return }
        log("Suppression définitive", target: trashEntries[index].entry.title)
        trashEntries.remove(at: index)
        persistEntries()
    }

    func emptyTrash() {
        if !trashEntries.isEmpty {
            log("Corbeille vidée", target: "\(trashEntries.count) élément(s)")
        }
        trashEntries.removeAll()
        persistEntries()
    }

    func purgeExpiredTrash() {
        let now = Date()
        let countBefore = trashEntries.count
        trashEntries.removeAll { $0.expiresAt <= now }
        if trashEntries.count != countBefore { persistEntries() }
    }

    func clearActivityLog() {
        guard !activityLog.isEmpty else { return }
        activityLog.removeAll()
        log("Journal purgé", target: "Historique local")
        persistEntries()
    }

    func rotateVaultKeyNow() {
        rotateVaultKeyIfNeeded(force: true)
        persistEntries()
    }

    // MARK: Queries

    func markCopied(_ type: String, title: String) {
        log("Copie \(type)", target: title)
        persistEntries()
    }

    func isPasswordReused(_ password: String, excluding entryID: UUID? = nil) -> Bool {
        let clean = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        return entries.contains { entry in
            if let entryID, entry.id == entryID { return false }
            return entry.password == clean
        }
    }

    // MARK: Security Audit

    var securityAudit: SecurityAudit {
        guard !entries.isEmpty else {
            return SecurityAudit(score: 100, weakCount: 0, reusedCount: 0, withoutMFACount: 0, expiredCount: 0, recommendations: ["Ajoute ton premier compte."])
        }

        let weakCount = entries.filter { [.faible, .moyen].contains(PasswordToolkit.strength(for: $0.password)) }.count
        let withoutMFA = entries.filter { !$0.mfaEnabled }.count
        let expiredCount = entries.filter { $0.isExpired }.count
        var duplicates = 0
        let grouped = Dictionary(grouping: entries, by: { $0.password })
        for (_, group) in grouped where group.count > 1 { duplicates += group.count }

        let total = entries.count
        let weakPenalty = Int(Double(weakCount) / Double(total) * 30.0)
        let reusePenalty = Int(Double(duplicates) / Double(total) * 30.0)
        let mfaPenalty = Int(Double(withoutMFA) / Double(total) * 25.0)
        let expiredPenalty = Int(Double(expiredCount) / Double(total) * 15.0)
        let score = max(0, 100 - weakPenalty - reusePenalty - mfaPenalty - expiredPenalty)

        var recommendations: [String] = []
        if weakCount > 0     { recommendations.append("Renforce \(weakCount) mot(s) de passe à améliorer.") }
        if duplicates > 0    { recommendations.append("Évite la réutilisation (\(duplicates) entrée(s)).") }
        if withoutMFA > 0    { recommendations.append("Active le MFA sur \(withoutMFA) compte(s).") }
        if expiredCount > 0  { recommendations.append("\(expiredCount) mot(s) de passe expiré(s) à renouveler.") }
        if recommendations.isEmpty { recommendations.append("Excellent niveau de sécurité.") }

        return SecurityAudit(score: score, weakCount: weakCount, reusedCount: duplicates, withoutMFACount: withoutMFA, expiredCount: expiredCount, recommendations: recommendations)
    }

    // MARK: Export / Import

    func exportCSV() -> String {
        var rows: [String] = ["title,username,password,website,notes,mfa,folder,tags,favorite,expiration_policy"]
        for e in entries {
            let row = [
                e.title, e.username, e.password, e.website, e.notes,
                e.mfaEnabled ? "yes" : "no",
                e.folder,
                e.tags.joined(separator: "|"),
                e.isFavorite ? "yes" : "no",
                e.expirationPolicy.label
            ].map(csvEscape).joined(separator: ",")
            rows.append(row)
        }
        log("Export CSV", target: "\(entries.count) entrée(s) — DONNÉES SENSIBLES")
        persistEntries()
        return rows.joined(separator: "\n")
    }

    func exportBitwardenCSV() -> String {
        let header = "folder,favorite,type,name,notes,fields,reprompt,login_uri,login_username,login_password,login_totp"
        var rows: [String] = [header]
        for e in entries {
            let fields = e.customFields.map { "\($0.key):\($0.value)" }.joined(separator: ";")
            let row = [e.folder, e.isFavorite ? "1" : "0", "login", e.title, e.notes, fields, "0",
                       e.website, e.username, e.password, e.mfaType == .totp ? e.mfaSecret : ""]
                .map(csvEscape).joined(separator: ",")
            rows.append(row)
        }
        log("Export Bitwarden CSV", target: "DONNÉES SENSIBLES")
        persistEntries()
        return rows.joined(separator: "\n")
    }

    func exportOnePasswordCSV() -> String {
        let header = "Title,Website,Username,Password,Notes,OTPAuth"
        var rows: [String] = [header]
        for e in entries {
            let row = [e.title, e.website, e.username, e.password, e.notes,
                       e.mfaType == .totp ? e.mfaSecret : ""]
                .map(csvEscape).joined(separator: ",")
            rows.append(row)
        }
        log("Export 1Password CSV", target: "DONNÉES SENSIBLES")
        persistEntries()
        return rows.joined(separator: "\n")
    }

    private func csvEscape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    func exportBackup(passphrase: String) throws -> Data {
        let clean = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 10 else { throw BackupError.invalidPassphrase }

        let payload = try JSONEncoder().encode(VaultDatabase(entries: entries, trash: trashEntries, activityLog: activityLog))
        let salt = CryptoService.makeSalt()
        let keyData = CryptoService.deriveBackupKey(passphrase: clean, salt: salt)
        let encrypted = try CryptoService.encrypt(data: payload, with: keyData)
        let signature = CryptoService.hmacSHA256(data: encrypted, key: keyData)
        let envelope = BackupEnvelope(version: 2, createdAt: Date(), salt: salt, cipherCombined: encrypted, signature: signature)
        log("Export backup chiffré", target: "Backup v2 — \(entries.count) entrée(s)")
        persistEntries()
        return try JSONEncoder().encode(envelope)
    }

    func importBackup(_ data: Data, passphrase: String) throws {
        let clean = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 10 else { throw BackupError.invalidPassphrase }
        let envelope = try JSONDecoder().decode(BackupEnvelope.self, from: data)
        let keyData = CryptoService.deriveBackupKey(passphrase: clean, salt: envelope.salt)
        let expected = CryptoService.hmacSHA256(data: envelope.cipherCombined, key: keyData)
        guard expected == envelope.signature else { throw BackupError.tamperedData }
        let decrypted = try CryptoService.decrypt(data: envelope.cipherCombined, with: keyData)
        let db = try JSONDecoder().decode(VaultDatabase.self, from: decrypted)
        entries = db.entries
        trashEntries = db.trash
        activityLog = db.activityLog
        log("Import backup restauré", target: "\(entries.count) entrée(s) restaurée(s)")
        persistEntries()
    }

    /// Exports the activity log as plain text
    func exportActivityLogText() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var lines = ["FyxxVault — Journal d'activité", "Exporté le \(formatter.string(from: Date()))", ""]
        for item in activityLog {
            lines.append("[\(formatter.string(from: item.date))] \(item.action) — \(item.target)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Panic

    func wipeVaultForPanicMode() {
        entries = []
        trashEntries = []
        activityLog = []
        try? FileManager.default.removeItem(at: fileURL)
        log("PANIC", target: "Coffre effacé")
        persistEntries()
    }

    // MARK: Private — Persistence (HMAC-wrapped vault file)

    private func loadEntries() {
        guard let keyData, let rawData = try? Data(contentsOf: fileURL) else {
            entries = []
            trashEntries = []
            integrityWarning = ""
            return
        }

        do {
            // Unwrap HMAC header (new format v3)
            let ciphertext: Data
            if rawData.prefix(4) == Data([0x46, 0x59, 0x58, 0x56]) { // "FYXV" magic
                ciphertext = try CryptoService.unwrapVaultData(rawData, keyData: keyData)
            } else {
                // Legacy: raw AES-GCM without HMAC header
                ciphertext = rawData
            }

            let decrypted = try CryptoService.decrypt(data: ciphertext, with: keyData)

            if let db = try? JSONDecoder().decode(VaultDatabase.self, from: decrypted) {
                entries = db.entries
                trashEntries = db.trash
                activityLog = db.activityLog
                integrityWarning = ""
            } else if let legacyEntries = try? JSONDecoder().decode([VaultEntry].self, from: decrypted) {
                // Migrate from legacy array format
                entries = legacyEntries
                trashEntries = []
                activityLog = []
                integrityWarning = ""
            } else {
                throw SecurityError.decryptionFailure
            }
        } catch SecurityError.tampered {
            entries = []
            trashEntries = []
            activityLog = []
            integrityWarning = "🚨 ALERTE: Le fichier coffre a été altéré. Données réinitialisées par sécurité."
        } catch {
            entries = []
            trashEntries = []
            activityLog = []
            integrityWarning = "Alerte: fichier coffre invalide ou corrompu."
        }
    }

    private func persistEntries() {
        guard let keyData else { return }
        persistenceError = ""

        do {
            let payload = try JSONEncoder().encode(
                VaultDatabase(entries: entries, trash: trashEntries, activityLog: activityLog)
            )
            let ciphertext = try CryptoService.encrypt(data: payload, with: keyData)
            // Wrap with HMAC header (v3 format)
            let vaultData = CryptoService.wrapVaultData(ciphertext: ciphertext, keyData: keyData)
            try vaultData.write(
                to: fileURL,
                options: Data.WritingOptions([.atomic, .completeFileProtection])
            )
            maybeCreateDailySnapshot()
        } catch {
            persistenceError = "Erreur critique: impossible de sauvegarder le coffre. \(error.localizedDescription)"
            log("ERREUR PERSISTENCE", target: error.localizedDescription)
        }
    }

    // MARK: Private — Activity Log

    private func log(_ action: String, target: String) {
        activityLog.insert(ActivityLogItem(action: action, target: target), at: 0)
        // Cap at 1000 entries — warn before purge
        if activityLog.count > 1000 {
            activityLog = Array(activityLog.prefix(1000))
        }
    }

    // MARK: Private — Key Rotation (monthly, transactional)

    private func rotateVaultKeyIfNeeded(force: Bool = false) {
        let last = UserDefaults.standard.object(forKey: SettingsKey.keyRotationDate) as? Date
        let needsRotation: Bool
        if force {
            needsRotation = true
        } else if let last {
            needsRotation = Date().timeIntervalSince(last) > 60 * 60 * 24 * 30
        } else {
            needsRotation = true
        }
        guard needsRotation, let previousKey = keyData else { return }

        let newKey = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let tempURL = fileURL.appendingPathExtension("rotationtmp")
        do {
            let payload = try JSONEncoder().encode(
                VaultDatabase(entries: entries, trash: trashEntries, activityLog: activityLog)
            )
            let ciphertext = try CryptoService.encrypt(data: payload, with: newKey)
            let wrapped = CryptoService.wrapVaultData(ciphertext: ciphertext, keyData: newKey)
            try wrapped.write(
                to: tempURL,
                options: Data.WritingOptions([.atomic, .completeFileProtection])
            )

            try CryptoService.replaceSymmetricKeyData(with: newKey)
            keyData = newKey

            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: fileURL)

            UserDefaults.standard.set(Date(), forKey: SettingsKey.keyRotationDate)
            log("Rotation clé", target: "Clé vault renouvelée (AES-256)")
        } catch {
            keyData = previousKey
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    // MARK: Private — Daily Snapshots

    private func maybeCreateDailySnapshot() {
        guard let keyData else { return }
        let now = Date()
        let calendar = Calendar.current
        if let last = UserDefaults.standard.object(forKey: SettingsKey.localSnapshotDate) as? Date,
           calendar.isDate(last, inSameDayAs: now) { return }

        do {
            let payload = try JSONEncoder().encode(
                VaultDatabase(entries: entries, trash: trashEntries, activityLog: activityLog)
            )
            let ciphertext = try CryptoService.encrypt(data: payload, with: keyData)
            let wrapped = CryptoService.wrapVaultData(ciphertext: ciphertext, keyData: keyData)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            let fileName = "snapshot-\(formatter.string(from: now)).fyxxsnap"
            let url = snapshotsDirectoryURL.appendingPathComponent(fileName)
            try wrapped.write(to: url, options: [.atomic, .completeFileProtection])
            UserDefaults.standard.set(now, forKey: SettingsKey.localSnapshotDate)
            trimOldSnapshots()
        } catch {
            // Silent — snapshot failure should not disrupt UX
        }
    }

    private func trimOldSnapshots() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: snapshotsDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let sorted = files.sorted {
            let ld = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rd = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return ld > rd
        }

        if sorted.count > snapshotRetentionCount {
            for url in sorted.dropFirst(snapshotRetentionCount) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
