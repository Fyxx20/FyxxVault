import XCTest
@testable import FyxxVault

final class PasswordToolkitTests: XCTestCase {

    // MARK: - Password Strength Classification

    func testEmptyPasswordIsFaible() {
        XCTAssertEqual(PasswordToolkit.strength(for: ""), .faible)
    }

    func testShortSimplePasswordIsFaible() {
        XCTAssertEqual(PasswordToolkit.strength(for: "abc"), .faible)
        XCTAssertEqual(PasswordToolkit.strength(for: "12345"), .faible)
    }

    func testMediumPassword() {
        // 14+ chars, has lower + upper + number = 5 points → moyen
        let result = PasswordToolkit.strength(for: "Abcdefghijklm1")
        XCTAssertTrue(result == .moyen || result == .fort)
    }

    func testStrongPassword() {
        // 14+ chars, lower + upper + number + symbol = 6 points → fort
        let result = PasswordToolkit.strength(for: "Abcdefghijklm1!")
        XCTAssertTrue(result == .fort || result == .excellent)
    }

    func testExcellentPassword() {
        // 20+ chars, all char types = 7 points → excellent
        XCTAssertEqual(PasswordToolkit.strength(for: "AbCdEfGhIjKlMnOpQrSt1!"), .excellent)
    }

    // MARK: - Password Generation (Random)

    func testGenerateRandomPasswordLength() {
        let policy = PasswordPolicy(length: 24, includeUppercase: true, includeLowercase: true, includeNumbers: true, includeSymbols: true)
        let password = PasswordToolkit.generate(policy: policy)
        XCTAssertEqual(password.count, 24)
    }

    func testGenerateRandomPasswordIncludesRequiredCharTypes() {
        let policy = PasswordPolicy(
            length: 20,
            includeUppercase: true,
            includeLowercase: true,
            includeNumbers: true,
            includeSymbols: true
        )

        // Generate many passwords and verify they all contain required types
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
        // All 100 passwords should be unique
        XCTAssertEqual(passwords.count, 100)
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
        XCTAssertTrue(password.allSatisfy { $0.isNumber })
    }

    // MARK: - Passphrase Generation

    func testGeneratePassphrase() {
        let policy = PasswordPolicy(mode: .passphrase, wordsCount: 4)
        let passphrase = PasswordToolkit.generate(policy: policy)
        let words = passphrase.split(separator: "-")
        XCTAssertEqual(words.count, 4)
    }

    func testGeneratePassphraseMinWords() {
        let policy = PasswordPolicy(mode: .passphrase, wordsCount: 1) // Should clamp to 3
        let passphrase = PasswordToolkit.generate(policy: policy)
        let words = passphrase.split(separator: "-")
        XCTAssertEqual(words.count, 3) // Minimum is 3
    }

    func testGeneratePassphraseMaxWords() {
        let policy = PasswordPolicy(mode: .passphrase, wordsCount: 20) // Should clamp to 8
        let passphrase = PasswordToolkit.generate(policy: policy)
        let words = passphrase.split(separator: "-")
        XCTAssertEqual(words.count, 8) // Maximum is 8
    }

    func testGeneratePassphraseWordsFromDictionary() {
        let policy = PasswordPolicy(mode: .passphrase, wordsCount: 5)
        let passphrase = PasswordToolkit.generate(policy: policy)
        let words = passphrase.split(separator: "-").map(String.init)

        for word in words {
            XCTAssertTrue(
                PasswordToolkit.passphraseDictionary.contains(word),
                "Word '\(word)' not found in dictionary"
            )
        }
    }

    // MARK: - Master Password Validation

    func testValidMasterPassword() {
        let (valid, error) = PasswordValidator.validateMasterPassword("MySecureP@ss1")
        XCTAssertTrue(valid)
        XCTAssertTrue(error.isEmpty)
    }

    func testTooShortPassword() {
        let (valid, _) = PasswordValidator.validateMasterPassword("Short1!")
        XCTAssertFalse(valid)
    }

    func testMissingUppercase() {
        let (valid, _) = PasswordValidator.validateMasterPassword("mysecurepass1!")
        XCTAssertFalse(valid)
    }

    func testMissingDigit() {
        let (valid, _) = PasswordValidator.validateMasterPassword("MySecurePass!!")
        XCTAssertFalse(valid)
    }

    func testMissingSpecialChar() {
        let (valid, _) = PasswordValidator.validateMasterPassword("MySecurePass12")
        XCTAssertFalse(valid)
    }

    func testRepetitivePassword() {
        let (valid, _) = PasswordValidator.validateMasterPassword("aaaaaaaaaaA1!")
        XCTAssertFalse(valid)
    }

    // MARK: - Email Validation

    func testValidEmails() {
        XCTAssertTrue(PasswordValidator.validateEmail("user@example.com"))
        XCTAssertTrue(PasswordValidator.validateEmail("user.name+tag@domain.co.uk"))
        XCTAssertTrue(PasswordValidator.validateEmail("test123@test.io"))
    }

    func testInvalidEmails() {
        XCTAssertFalse(PasswordValidator.validateEmail(""))
        XCTAssertFalse(PasswordValidator.validateEmail("notanemail"))
        XCTAssertFalse(PasswordValidator.validateEmail("@domain.com"))
        XCTAssertFalse(PasswordValidator.validateEmail("user@"))
        XCTAssertFalse(PasswordValidator.validateEmail("user@.com"))
    }
}
