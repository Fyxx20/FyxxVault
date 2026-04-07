import Foundation

enum ImportFormat: String, CaseIterable, Identifiable {
    case bitwardenCSV = "Bitwarden CSV"
    case onePasswordCSV = "1Password CSV"
    case genericCSV = "CSV Générique"
    var id: String { rawValue }
}

enum ImportDuplicateStrategy: String, CaseIterable, Identifiable {
    case skip = "Ignorer les doublons"
    case overwrite = "Écraser les existants"
    case keepBoth = "Garder les deux"
    var id: String { rawValue }
}

struct ImportResult {
    var entries: [VaultEntry]
    var duplicateCount: Int
    var skippedCount: Int
    var errorMessages: [String]
}

struct CSVColumnMapping {
    var titleColumn: Int?
    var usernameColumn: Int?
    var passwordColumn: Int?
    var websiteColumn: Int?
    var notesColumn: Int?
    var folderColumn: Int?
    var totpColumn: Int?
}

enum ImportService {

    // MARK: - Format Detection

    static func detectFormat(from csvText: String) -> ImportFormat? {
        let firstLine = csvText.components(separatedBy: .newlines).first?.lowercased() ?? ""
        if firstLine.contains("login_uri") && firstLine.contains("login_username") {
            return .bitwardenCSV
        }
        if firstLine.contains("title") && firstLine.contains("username") && firstLine.contains("otpauth") {
            return .onePasswordCSV
        }
        return nil
    }

    // MARK: - Bitwarden CSV Parser

    static func parseBitwardenCSV(_ text: String) -> [VaultEntry] {
        let rows = parseCSVRows(text)
        guard rows.count > 1 else { return [] }
        let header = rows[0].map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }

        let folderIdx = header.firstIndex(of: "folder")
        let favoriteIdx = header.firstIndex(of: "favorite")
        let typeIdx = header.firstIndex(of: "type")
        let nameIdx = header.firstIndex(of: "name")
        let notesIdx = header.firstIndex(of: "notes")
        let fieldsIdx = header.firstIndex(of: "fields")
        let uriIdx = header.firstIndex(of: "login_uri")
        let usernameIdx = header.firstIndex(of: "login_username")
        let passwordIdx = header.firstIndex(of: "login_password")
        let totpIdx = header.firstIndex(of: "login_totp")

        var entries: [VaultEntry] = []

        for row in rows.dropFirst() {
            guard row.count >= 4 else { continue }
            let get: (Int?) -> String = { idx in
                guard let i = idx, i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let title = get(nameIdx)
            guard !title.isEmpty else { continue }

            let typeStr = get(typeIdx).lowercased()
            let category: VaultCategory
            switch typeStr {
            case "card": category = .creditCard
            case "identity": category = .identity
            case "securenote": category = .secureNote
            default: category = .login
            }

            let password = get(passwordIdx)
            let totpSecret = get(totpIdx)

            // Parse custom fields (semicolon-separated key:value)
            var customFields: [VaultCustomField] = []
            let fieldsStr = get(fieldsIdx)
            if !fieldsStr.isEmpty {
                for pair in fieldsStr.components(separatedBy: ";") {
                    let parts = pair.components(separatedBy: ":")
                    if parts.count >= 2 {
                        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let value = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !key.isEmpty {
                            customFields.append(VaultCustomField(key: key, value: value))
                        }
                    }
                }
            }

            let entry = VaultEntry(
                title: title,
                username: get(usernameIdx),
                password: password,
                website: get(uriIdx),
                notes: get(notesIdx),
                mfaEnabled: !totpSecret.isEmpty,
                mfaType: totpSecret.isEmpty ? nil : .totp,
                mfaSecret: totpSecret,
                folder: get(folderIdx),
                isFavorite: get(favoriteIdx) == "1",
                customFields: customFields,
                category: category
            )
            entries.append(entry)
        }
        return entries
    }

    // MARK: - 1Password CSV Parser

    static func parseOnePasswordCSV(_ text: String) -> [VaultEntry] {
        let rows = parseCSVRows(text)
        guard rows.count > 1 else { return [] }
        let header = rows[0].map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }

        let titleIdx = header.firstIndex(of: "title")
        let urlIdx = header.firstIndex(of: "url") ?? header.firstIndex(of: "website")
        let usernameIdx = header.firstIndex(of: "username")
        let passwordIdx = header.firstIndex(of: "password")
        let notesIdx = header.firstIndex(of: "notes")
        let otpIdx = header.firstIndex(of: "otpauth") ?? header.firstIndex(of: "otp")

        var entries: [VaultEntry] = []

        for row in rows.dropFirst() {
            guard row.count >= 3 else { continue }
            let get: (Int?) -> String = { idx in
                guard let i = idx, i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let title = get(titleIdx)
            guard !title.isEmpty else { continue }

            let otpSecret = get(otpIdx)

            let entry = VaultEntry(
                title: title,
                username: get(usernameIdx),
                password: get(passwordIdx),
                website: get(urlIdx),
                notes: get(notesIdx),
                mfaEnabled: !otpSecret.isEmpty,
                mfaType: otpSecret.isEmpty ? nil : .totp,
                mfaSecret: otpSecret,
                category: .login
            )
            entries.append(entry)
        }
        return entries
    }

    // MARK: - Generic CSV Parser

    static func parseGenericCSV(_ text: String, mapping: CSVColumnMapping) -> [VaultEntry] {
        let rows = parseCSVRows(text)
        guard rows.count > 1 else { return [] }

        var entries: [VaultEntry] = []

        for row in rows.dropFirst() {
            let get: (Int?) -> String = { idx in
                guard let i = idx, i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let title = get(mapping.titleColumn)
            guard !title.isEmpty else { continue }

            let totpSecret = get(mapping.totpColumn)

            let entry = VaultEntry(
                title: title,
                username: get(mapping.usernameColumn),
                password: get(mapping.passwordColumn),
                website: get(mapping.websiteColumn),
                notes: get(mapping.notesColumn),
                mfaEnabled: !totpSecret.isEmpty,
                mfaType: totpSecret.isEmpty ? nil : .totp,
                mfaSecret: totpSecret,
                folder: get(mapping.folderColumn),
                category: .login
            )
            entries.append(entry)
        }
        return entries
    }

    // MARK: - CSV Row Parser (handles quoted fields)

    static func parseCSVRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0

        while i < chars.count {
            let c = chars[i]

            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        inQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    currentField.append(c)
                    i += 1
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                    i += 1
                } else if c == "," {
                    currentRow.append(currentField)
                    currentField = ""
                    i += 1
                } else if c == "\n" || c == "\r" {
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.allSatisfy({ $0.isEmpty }) {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    if c == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" {
                        i += 2
                    } else {
                        i += 1
                    }
                } else {
                    currentField.append(c)
                    i += 1
                }
            }
        }

        // Last field/row
        currentRow.append(currentField)
        if !currentRow.allSatisfy({ $0.isEmpty }) {
            rows.append(currentRow)
        }

        return rows
    }

    // MARK: - Deduplication

    static func deduplicate(
        imported: [VaultEntry],
        existing: [VaultEntry],
        strategy: ImportDuplicateStrategy
    ) -> ImportResult {
        var result: [VaultEntry] = []
        var duplicateCount = 0
        var skippedCount = 0

        for entry in imported {
            let isDuplicate = existing.contains { ex in
                ex.title.lowercased() == entry.title.lowercased() &&
                ex.username.lowercased() == entry.username.lowercased()
            }

            if isDuplicate {
                duplicateCount += 1
                switch strategy {
                case .skip:
                    skippedCount += 1
                case .overwrite, .keepBoth:
                    result.append(entry)
                }
            } else {
                result.append(entry)
            }
        }

        return ImportResult(
            entries: result,
            duplicateCount: duplicateCount,
            skippedCount: skippedCount,
            errorMessages: []
        )
    }

    // MARK: - Headers extraction for generic CSV

    static func extractHeaders(from csvText: String) -> [String] {
        let rows = parseCSVRows(csvText)
        guard let first = rows.first else { return [] }
        return first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
