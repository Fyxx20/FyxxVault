import XCTest
@testable import FyxxVault

final class PasswordToolkitTests: XCTestCase {

    // MARK: - Password Generation (Random)

    func testGenerateRandomPassword() {
        let policy = PasswordPolicy(length: 20,
                                    includeUppercase: true,
                                    includeLowercase: true,
                                    includeNumbers: true,
                                    includeSymbols: true,
                                    mode: .random)
        let password = PasswordToolkit.generate(policy: policy)
        XCTAssertEqual(password.count, 20, "Generated password must match requested length")
    }

    func testGenerateRandomPasswordIncludesRequiredCharTypes() {
        let policy = PasswordPolicy(
            length: 20,
            includeUppercase: true,
            includeLowercase: true,
            includeNumbers: true,
            includeSymbols: true
        )

        // Generate many passwords and verify they contain required types
        for _ in 0..<50 {
            let password = PasswordToolkit.generate(policy: policy)
            XCTAssertTrue(password.rangeOfCharacter(from: .uppercaseLetters) != nil, "Missing uppercase in: \(password)")
            XCTAssertTrue(password.rangeOfCharacter(from: .lowercaseLetters) != nil, "Missing lowercase in: \(password)")
            XCTAssertTrue(password.rangeOfCharacter(from: .decimalDigits) != nil, "Missing number in: \(password)")
        }
    }

    func testGenerateRandomPasswordUniqueness() {
        let policy = PasswordPolicy(length: 20)
        var passwords = Set<String>()
        for _ in 0..<100 {
            passwords.insert(PasswordToolkit.generate(policy: policy))
        }
        XCTAssertEqual(passwords.count, 100, "100 generated passwords must all be unique")
    }

    func testGenerateWithOnlyNumbers() {
        let policy = PasswordPolicy(
            length: 10,
            includeUppercase: false,
            includeLowercase: false,
            includeNumbers: true,
            includeSymbols: false
        )
        let password = PasswordToolkit.generate(policy: policy)
        XCTAssertEqual(password.count, 10)
        XCTAssertTrue(password.allSatisfy { $0.isNumber }, "All characters must be digits")
    }

    // MARK: - Passphrase Generation

    func testGeneratePassphrase() {
        let policy = PasswordPolicy(mode: .passphrase, wordsCount: 4)
        let passphrase = PasswordToolkit.generate(policy: policy)
        let words = passphrase.split(separator: "-")
        XCTAssertEqual(words.count, 4, "Passphrase must have the requested number of words")
        XCTAssertTrue(passphrase.contains("-"), "Words must be separated by dashes")
    }

    func testGeneratePassphraseMinWords() {
        let policy = PasswordPolicy(mode: .passphrase, wordsCount: 1) // Clamped to 3
        let passphrase = PasswordToolkit.generate(policy: policy)
        let words = passphrase.split(separator: "-")
        XCTAssertEqual(words.count, 3, "Minimum word count must be 3")
    }

    func testGeneratePassphraseMaxWords() {
        let policy = PasswordPolicy(mode: .passphrase, wordsCount: 20) // Clamped to 8
        let passphrase = PasswordToolkit.generate(policy: policy)
        let words = passphrase.split(separator: "-")
        XCTAssertEqual(words.count, 8, "Maximum word count must be 8")
    }

    func testGeneratePassphraseWordsFromDictionary() {
        let policy = PasswordPolicy(mode: .passphrase, wordsCount: 5)
        let passphrase = PasswordToolkit.generate(policy: policy)
        let words = passphrase.split(separator: "-").map(String.init)

        for word in words {
            XCTAssertTrue(
                PasswordToolkit.passphraseDictionary.contains(word),
                "Word '\(word)' must be in the dictionary"
            )
        }
    }

    // MARK: - Password Strength

    func testPasswordStrengthFaible() {
        XCTAssertEqual(PasswordToolkit.strength(for: "abc"), .faible, "'abc' must be rated faible")
        XCTAssertEqual(PasswordToolkit.strength(for: ""), .faible, "Empty string must be faible")
        XCTAssertEqual(PasswordToolkit.strength(for: "12345"), .faible, "'12345' must be faible")
    }

    func testPasswordStrengthExcellent() {
        // 22 chars, upper + lower + digit + symbol, length >= 20 => score 7 => excellent
        let strength = PasswordToolkit.strength(for: "AbCdEfGhIjKlMnOpQrSt1!")
        XCTAssertEqual(strength, .excellent, "Complex 22-char password must be excellent")
    }

    func testPasswordStrengthFortOrExcellent() {
        // 17 chars with all character types
        let strength = PasswordToolkit.strength(for: "Tr0ub4dor&3!xKz9Q")
        XCTAssertTrue(strength == .excellent || strength == .fort,
                      "A complex 18-char password must be fort or excellent")
    }

    func testPasswordStrengthMoyen() {
        // 14+ chars, lower + upper + number = score 5 => moyen
        let result = PasswordToolkit.strength(for: "Abcdefghijklm1")
        XCTAssertTrue(result == .moyen || result == .fort)
    }

    // MARK: - Master Password Validation

    func testMasterPasswordValidation() {
        let (valid, message) = PasswordValidator.validateMasterPassword("MyP@ssw0rd123!")
        XCTAssertTrue(valid, "Valid master password must pass")
        XCTAssertTrue(message.isEmpty, "Error message must be empty for valid password")
    }

    func testMasterPasswordTooShort() {
        let (valid, _) = PasswordValidator.validateMasterPassword("Ab1!")
        XCTAssertFalse(valid, "Password shorter than 12 chars must fail")
    }

    func testMasterPasswordNoUppercase() {
        let (valid, _) = PasswordValidator.validateMasterPassword("abcdefgh1234!")
        XCTAssertFalse(valid, "Password without uppercase must fail")
    }

    func testMasterPasswordNoDigit() {
        let (valid, _) = PasswordValidator.validateMasterPassword("Abcdefghijklm!")
        XCTAssertFalse(valid, "Password without digit must fail")
    }

    func testMasterPasswordNoSpecial() {
        let (valid, _) = PasswordValidator.validateMasterPassword("Abcdefghijk123")
        XCTAssertFalse(valid, "Password without special character must fail")
    }

    func testMasterPasswordValid() {
        let (valid, msg) = PasswordValidator.validateMasterPassword("MyP@ssw0rd123!")
        XCTAssertTrue(valid)
        XCTAssertEqual(msg, "")
    }

    func testMasterPasswordRepetitive() {
        let (valid, _) = PasswordValidator.validateMasterPassword("aaaaaaaaaaA1!")
        XCTAssertFalse(valid, "Repetitive password must fail")
    }

    // MARK: - Email Validation

    func testEmailValidation() {
        XCTAssertTrue(PasswordValidator.validateEmail("user@example.com"), "Standard email must be valid")
        XCTAssertTrue(PasswordValidator.validateEmail("a.b+c@sub.domain.org"), "Complex email must be valid")
        XCTAssertTrue(PasswordValidator.validateEmail("test123@test.io"), "Numeric local part must be valid")
        XCTAssertFalse(PasswordValidator.validateEmail("not-an-email"), "Missing @ must be invalid")
        XCTAssertFalse(PasswordValidator.validateEmail("@domain.com"), "Missing local part must be invalid")
        XCTAssertFalse(PasswordValidator.validateEmail("user@"), "Missing domain must be invalid")
        XCTAssertFalse(PasswordValidator.validateEmail("user@.com"), "Dot-only domain must be invalid")
        XCTAssertFalse(PasswordValidator.validateEmail(""), "Empty string must be invalid")
    }

    // MARK: - Policy Respect

    func testPasswordGenerationRespectPolicy() {
        let policy = PasswordPolicy(length: 30,
                                    includeUppercase: true,
                                    includeLowercase: true,
                                    includeNumbers: true,
                                    includeSymbols: false,
                                    mode: .random)
        // Generate multiple times to reduce false-negative risk
        for _ in 0..<10 {
            let password = PasswordToolkit.generate(policy: policy)
            let symbols = CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{};:,.?/\\")
            let hasSymbol = password.unicodeScalars.contains(where: { symbols.contains($0) })
            XCTAssertFalse(hasSymbol, "Password must not contain symbols when includeSymbols is false: \(password)")
        }
    }
}
