import Foundation
import Security
import CryptoKit
import CommonCrypto
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

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

// MARK: - Crypto Service

enum CryptoService {
    static let defaultMasterRounds = 210_000
    /// Magic bytes prepended to the vault file for quick format identification
    private static let vaultMagic: [UInt8] = [0x46, 0x59, 0x58, 0x56] // "FYXV"

    // MARK: Master Password Hashing

    static func hashMasterPasswordPBKDF2(_ password: String, salt: Data, rounds: Int = defaultMasterRounds) -> String {
        let key = pbkdf2SHA256(password: Data(password.utf8), salt: salt, rounds: rounds, keyLength: 32)
        return key.map { String(format: "%02x", $0) }.joined()
    }

    static func verifyMasterPassword(_ password: String, account: Account) -> Bool {
        if account.passwordHashAlgorithm == "pbkdf2-sha256" {
            let rounds = max(account.passwordHashRounds, 100_000)
            return hashMasterPasswordPBKDF2(password, salt: account.passwordSalt, rounds: rounds) == account.passwordHash
        }
        return hashPasswordLegacy(password, salt: account.passwordSalt) == account.passwordHash
    }

    static func masterRounds() -> Int { defaultMasterRounds }

    private static func hashPasswordLegacy(_ password: String, salt: Data) -> String {
        var payload = Data()
        payload.append(salt)
        payload.append(Data(password.utf8))
        return SHA256.hash(data: payload).compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: Key Material

    static func makeSalt() -> Data {
        Data((0..<16).map { _ in UInt8.random(in: 0...255) })
    }

    static func deriveBackupKey(passphrase: String, salt: Data) -> Data {
        pbkdf2SHA256(password: Data(passphrase.utf8), salt: salt, rounds: 120_000, keyLength: 32)
    }

    static func hmacSHA256(data: Data, key: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key)))
    }

    static func symmetricKeyData() throws -> Data {
        if let existing = KeychainService.loadOptionalData(for: SecureStoreKey.vaultSymmetricKey) {
            return existing
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        try KeychainService.save(data: keyData, key: SecureStoreKey.vaultSymmetricKey)
        return keyData
    }

    static func replaceSymmetricKeyData(with data: Data) throws {
        try KeychainService.save(data: data, key: SecureStoreKey.vaultSymmetricKey)
    }

    // MARK: Encryption / Decryption

    static func encrypt(data: Data, with keyData: Data) throws -> Data {
        let key = SymmetricKey(data: keyData)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw SecurityError.encryptionFailure
        }
        return combined
    }

    static func decrypt(data: Data, with keyData: Data) throws -> Data {
        let key = SymmetricKey(data: keyData)
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    // MARK: Vault File Format (HMAC-wrapped)
    //
    // Layout: [4 magic][32 HMAC-SHA256][N AES-GCM ciphertext]
    //
    // The HMAC provides a fast integrity check without full decryption.
    // AES-GCM itself already authenticates; HMAC adds defense-in-depth.

    static func wrapVaultData(ciphertext: Data, keyData: Data) -> Data {
        let hmac = hmacSHA256(data: ciphertext, key: keyData)
        var result = Data(vaultMagic)
        result.append(hmac)
        result.append(ciphertext)
        return result
    }

    static func unwrapVaultData(_ raw: Data, keyData: Data) throws -> Data {
        let magicCount = vaultMagic.count
        let hmacCount = 32
        let headerSize = magicCount + hmacCount

        guard raw.count > headerSize else { throw SecurityError.tampered }

        let magic = Array(raw.prefix(magicCount))
        guard magic == vaultMagic else { throw SecurityError.tampered }

        let storedHMAC = raw.dropFirst(magicCount).prefix(hmacCount)
        let ciphertext = raw.dropFirst(headerSize)

        let expectedHMAC = hmacSHA256(data: ciphertext, key: keyData)
        guard storedHMAC == expectedHMAC else { throw SecurityError.tampered }

        return Data(ciphertext)
    }

    // MARK: Recovery Key

    /// Generates a 32-character uppercase alphanumeric recovery key.
    /// Displayed as 8 groups of 4 characters: XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX
    static func generateRecoveryKey() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return (0..<32).map { _ in String(chars.randomElement()!) }.joined()
    }

    static func formatRecoveryKey(_ raw: String) -> String {
        stride(from: 0, to: raw.count, by: 4).map { i in
            let start = raw.index(raw.startIndex, offsetBy: i)
            let end = raw.index(start, offsetBy: min(4, raw.count - i))
            return String(raw[start..<end])
        }.joined(separator: "-")
    }

    static func hashRecoveryKey(_ key: String, salt: Data) -> String {
        // Normalise: remove dashes, uppercase
        let clean = key.replacingOccurrences(of: "-", with: "").uppercased()
        return hashMasterPasswordPBKDF2(clean, salt: salt, rounds: 100_000)
    }

    static func verifyRecoveryKey(_ key: String, account: Account) -> Bool {
        guard let hash = account.recoveryKeyHash,
              let salt = account.recoveryKeySalt else { return false }
        let clean = key.replacingOccurrences(of: "-", with: "").uppercased()
        return hashRecoveryKey(clean, salt: salt) == hash
    }

    // MARK: PBKDF2

    static func pbkdf2SHA256(password: Data, salt: Data, rounds: Int, keyLength: Int) -> Data {
        var derived = Data(repeating: 0, count: keyLength)
        let rounds32 = UInt32(max(rounds, 1))
        _ = derived.withUnsafeMutableBytes { derivedBytes in
            password.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        password.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        rounds32,
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        keyLength
                    )
                }
            }
        }
        return derived
    }
}

// MARK: - Password Validator

enum PasswordValidator {
    /// Returns (isValid, errorMessage). Empty errorMessage means valid.
    static func validateMasterPassword(_ password: String) -> (Bool, String) {
        guard password.count >= 12 else {
            return (false, "Au moins 12 caractères requis.")
        }
        guard password.rangeOfCharacter(from: .uppercaseLetters) != nil else {
            return (false, "Au moins 1 lettre majuscule requise.")
        }
        guard password.rangeOfCharacter(from: .decimalDigits) != nil else {
            return (false, "Au moins 1 chiffre requis.")
        }
        let specials = CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:,.<>?/\\\"'`~")
        guard password.rangeOfCharacter(from: specials) != nil else {
            return (false, "Au moins 1 caractère spécial requis (!@#$%...)")
        }
        // Reject trivial repetitions like "aaaaaaaaaaaa"
        if isRepetitive(password) {
            return (false, "Mot de passe trop répétitif.")
        }
        return (true, "")
    }

    static func validateEmail(_ email: String) -> Bool {
        let pattern = #"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isRepetitive(_ s: String) -> Bool {
        guard s.count >= 4 else { return false }
        let chars = Array(s)
        // Check if >70% of characters are the same
        let freq = Dictionary(grouping: chars, by: { $0 })
        if let maxCount = freq.values.map(\.count).max(), maxCount > s.count * 7 / 10 {
            return true
        }
        // Check for consecutive sequences like "abcabc" repeated
        return false
    }
}

// MARK: - Password Breach Service

enum PasswordBreachService {
    static func compromisedCount(password: String) async -> Int? {
        guard !password.isEmpty else { return nil }
        let hash = Insecure.SHA1.hash(data: Data(password.utf8)).map { String(format: "%02X", $0) }.joined()
        let prefix = String(hash.prefix(5))
        let suffix = String(hash.dropFirst(5))
        guard let url = URL(string: "https://api.pwnedpasswords.com/range/\(prefix)") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("FyxxVault-SecureVault/3.0", forHTTPHeaderField: "User-Agent")
        request.setValue("true", forHTTPHeaderField: "Add-Padding")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let body = String(data: data, encoding: .utf8) else { return nil }

        for line in body.split(separator: "\n") {
            let parts = line.split(separator: ":")
            guard parts.count == 2 else { continue }
            let left = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let right = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            if left == suffix { return Int(right) }
        }
        return 0
    }
}

// MARK: - TOTP Service

enum TOTPService {
    static func snapshot(secretInput: String, at date: Date = Date()) -> TOTPSnapshot? {
        guard let parsed = parseInput(secretInput) else { return nil }
        guard let key = base32DecodeToData(parsed.secret) else { return nil }

        let period = max(parsed.period, 1)
        let counter = UInt64(floor(date.timeIntervalSince1970 / Double(period)))
        var counterBigEndian = counter.bigEndian
        let counterData = Data(bytes: &counterBigEndian, count: MemoryLayout<UInt64>.size)

        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: SymmetricKey(data: key))
        let hmacData = Data(hmac)
        guard let lastByte = hmacData.last else { return nil }
        let offset = Int(lastByte & 0x0f)
        guard offset + 4 <= hmacData.count else { return nil }

        let slice = hmacData[offset..<offset + 4]
        var truncated = UInt32(slice[slice.startIndex]) << 24
        truncated |= UInt32(slice[slice.startIndex + 1]) << 16
        truncated |= UInt32(slice[slice.startIndex + 2]) << 8
        truncated |= UInt32(slice[slice.startIndex + 3])
        truncated &= 0x7fffffff

        let mod = UInt32(pow(10.0, Double(parsed.digits)))
        let otp = truncated % mod
        let code = String(format: "%0*u", parsed.digits, otp)

        let elapsed = Int(date.timeIntervalSince1970) % period
        let remaining = period - elapsed
        return TOTPSnapshot(code: code, remainingSeconds: remaining)
    }

    private static func parseInput(_ input: String) -> (secret: String, digits: Int, period: Int)? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.lowercased().hasPrefix("otpauth://"),
           let components = URLComponents(string: trimmed) {
            let query = components.queryItems ?? []
            let secret = query.first(where: { $0.name.lowercased() == "secret" })?.value ?? ""
            let digits = Int(query.first(where: { $0.name.lowercased() == "digits" })?.value ?? "") ?? 6
            let period = Int(query.first(where: { $0.name.lowercased() == "period" })?.value ?? "") ?? 30
            guard !secret.isEmpty else { return nil }
            return (secret, max(6, min(digits, 8)), max(15, min(period, 120)))
        }
        return (trimmed, 6, 30)
    }

    private static func base32DecodeToData(_ string: String) -> Data? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var lookup: [Character: UInt8] = [:]
        for (index, c) in alphabet.enumerated() {
            lookup[c] = UInt8(index)
        }

        let clean = string.uppercased()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        guard !clean.isEmpty else { return nil }

        var buffer: UInt32 = 0
        var bitsLeft: Int = 0
        var output = Data()

        for c in clean {
            guard let value = lookup[c] else { return nil }
            buffer = (buffer << 5) | UInt32(value)
            bitsLeft += 5
            while bitsLeft >= 8 {
                let shift = bitsLeft - 8
                output.append(UInt8((buffer >> UInt32(shift)) & 0xff))
                bitsLeft -= 8
                buffer &= (1 << UInt32(bitsLeft)) - 1
            }
        }
        return output.isEmpty ? nil : output
    }
}

// MARK: - Clipboard Service

enum ClipboardService {
    private static var clearTask: DispatchWorkItem?

    static func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        scheduleClear(text: text)
    }

    private static func scheduleClear(text: String) {
        let autoClear = UserDefaults.standard.bool(forKey: SettingsKey.clipboardAutoClear)
        guard autoClear else { return }
        let delay = UserDefaults.standard.integer(forKey: SettingsKey.clipboardDelay)
        let seconds = [15, 30, 60].contains(delay) ? delay : 30

        clearTask?.cancel()
        let task = DispatchWorkItem { clearIfSame(text: text) }
        clearTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds), execute: task)
    }

    private static func clearIfSame(text: String) {
        #if canImport(UIKit)
        if (UIKit.UIPasteboard.general.string ?? "") == text {
            UIKit.UIPasteboard.general.string = ""
        }
        #elseif canImport(AppKit)
        if AppKit.NSPasteboard.general.string(forType: .string) == text {
            AppKit.NSPasteboard.general.clearContents()
        }
        #endif
    }
}

// MARK: - Password Toolkit

enum PasswordToolkit {
    static let passphraseDictionary = [
        "acier", "atlas", "pixel", "lune", "omega", "lumen", "delta", "kilo",
        "sable", "fjord", "neon", "bravo", "cyber", "vortex", "crystal", "nova",
        "zenith", "alpha", "vertex", "rocket", "onyx", "quartz", "aurora", "cipher",
        "forge", "nexus", "prime", "ultra", "frost", "blaze", "storm", "flash"
    ]

    static func generate(policy: PasswordPolicy) -> String {
        if policy.mode == .passphrase {
            let count = max(3, min(policy.wordsCount, 8))
            return (0..<count).compactMap { _ in passphraseDictionary.randomElement() }.joined(separator: "-")
        }

        let uppercase = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
        let lowercase = Array("abcdefghijkmnopqrstuvwxyz")
        let numbers = Array("0123456789")
        let symbols = Array("!@#$%^&*()-_=+[]{};:,.?/\\")

        var pool: [Character] = []
        var forced: [Character] = []

        if policy.includeUppercase { pool += uppercase; if let c = uppercase.randomElement() { forced.append(c) } }
        if policy.includeLowercase { pool += lowercase; if let c = lowercase.randomElement() { forced.append(c) } }
        if policy.includeNumbers   { pool += numbers;   if let c = numbers.randomElement()   { forced.append(c) } }
        if policy.includeSymbols   { pool += symbols;   if let c = symbols.randomElement()   { forced.append(c) } }

        if pool.isEmpty { pool = lowercase }

        let targetLength = max(policy.length, forced.count)
        var characters = forced
        while characters.count < targetLength {
            if let c = pool.randomElement() { characters.append(c) }
        }
        return String(characters.shuffled())
    }

    static func strength(for password: String) -> PasswordStrength {
        guard !password.isEmpty else { return .faible }
        let length = password.count
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSymbol = password.rangeOfCharacter(from: CharacterSet.punctuationCharacters.union(.symbols)) != nil

        var score = 0
        if length >= 10 { score += 1 }
        if length >= 14 { score += 1 }
        if length >= 20 { score += 1 }
        if hasUppercase { score += 1 }
        if hasLowercase { score += 1 }
        if hasNumber    { score += 1 }
        if hasSymbol    { score += 1 }

        switch score {
        case 0...3: return .faible
        case 4...5: return .moyen
        case 6:     return .fort
        default:    return .excellent
        }
    }
}
