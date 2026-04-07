import Foundation

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
