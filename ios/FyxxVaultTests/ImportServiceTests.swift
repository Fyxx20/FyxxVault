import XCTest
@testable import FyxxVault

final class ImportServiceTests: XCTestCase {

    // MARK: - Format Detection

    func testDetectBitwardenFormat() {
        let csv = "folder,favorite,type,name,notes,fields,login_uri,login_username,login_password,login_totp\n"
        let format = ImportService.detectFormat(from: csv)
        XCTAssertEqual(format, .bitwardenCSV, "Header with login_uri must detect as Bitwarden CSV")
    }

    func testDetectOnePasswordFormat() {
        let csv = "Title,Url,Username,Password,Notes,OTPAuth\n"
        let format = ImportService.detectFormat(from: csv)
        XCTAssertEqual(format, .onePasswordCSV, "Header with Title/Username/OTPAuth must detect as 1Password CSV")
    }

    func testDetectUnknownFormat() {
        let csv = "col1,col2,col3\nval1,val2,val3\n"
        let format = ImportService.detectFormat(from: csv)
        XCTAssertNil(format, "Unrecognized header must return nil")
    }

    // MARK: - Bitwarden CSV Parsing

    func testParseBitwardenCSV() {
        let csv = """
        folder,favorite,type,name,notes,fields,login_uri,login_username,login_password,login_totp
        Social,1,login,Twitter,my notes,,https://twitter.com,john@mail.com,s3cret,JBSWY3DPEHPK3PXP
        Work,0,login,GitHub,,,https://github.com,dev@mail.com,gh-pass,
        """

        let entries = ImportService.parseBitwardenCSV(csv)

        XCTAssertEqual(entries.count, 2, "Must parse 2 entries")

        let twitter = entries[0]
        XCTAssertEqual(twitter.title, "Twitter")
        XCTAssertEqual(twitter.username, "john@mail.com")
        XCTAssertEqual(twitter.password, "s3cret")
        XCTAssertEqual(twitter.website, "https://twitter.com")
        XCTAssertEqual(twitter.notes, "my notes")
        XCTAssertEqual(twitter.folder, "Social")
        XCTAssertTrue(twitter.isFavorite, "favorite=1 must set isFavorite to true")
        XCTAssertTrue(twitter.mfaEnabled, "Non-empty TOTP must enable MFA")
        XCTAssertEqual(twitter.mfaSecret, "JBSWY3DPEHPK3PXP")

        let github = entries[1]
        XCTAssertEqual(github.title, "GitHub")
        XCTAssertFalse(github.isFavorite, "favorite=0 must set isFavorite to false")
        XCTAssertFalse(github.mfaEnabled, "Empty TOTP must not enable MFA")
    }

    // MARK: - 1Password CSV Parsing

    func testParseOnePasswordCSV() {
        let csv = """
        Title,Url,Username,Password,Notes,OTPAuth
        MyBank,https://bank.com,user1,bankpass,important,otpauth://totp/Bank?secret=JBSWY3DPEHPK3PXP
        Email,https://mail.com,user2,mailpass,,
        """

        let entries = ImportService.parseOnePasswordCSV(csv)

        XCTAssertEqual(entries.count, 2)

        let bank = entries[0]
        XCTAssertEqual(bank.title, "MyBank")
        XCTAssertEqual(bank.username, "user1")
        XCTAssertEqual(bank.password, "bankpass")
        XCTAssertEqual(bank.website, "https://bank.com")
        XCTAssertEqual(bank.notes, "important")
        XCTAssertTrue(bank.mfaEnabled)

        let email = entries[1]
        XCTAssertEqual(email.title, "Email")
        XCTAssertFalse(email.mfaEnabled)
    }

    // MARK: - Generic CSV Parsing

    func testParseGenericCSV() {
        let csv = """
        Site,Login,Pass,URL,Remarques
        Amazon,buyer@mail.com,amzn123,https://amazon.com,Prime account
        """

        let mapping = CSVColumnMapping(
            titleColumn: 0,
            usernameColumn: 1,
            passwordColumn: 2,
            websiteColumn: 3,
            notesColumn: 4,
            folderColumn: nil,
            totpColumn: nil
        )

        let entries = ImportService.parseGenericCSV(csv, mapping: mapping)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].title, "Amazon")
        XCTAssertEqual(entries[0].username, "buyer@mail.com")
        XCTAssertEqual(entries[0].password, "amzn123")
        XCTAssertEqual(entries[0].website, "https://amazon.com")
    }

    // MARK: - CSV Quoted Fields

    func testCSVQuotedFields() {
        let csv = """
        name,password,notes
        "My Site","pass,word","He said ""hello"""
        """

        let rows = ImportService.parseCSVRows(csv)
        XCTAssertEqual(rows.count, 2, "Must have header + 1 data row")

        let dataRow = rows[1]
        XCTAssertEqual(dataRow[0], "My Site", "Quoted field must strip surrounding quotes")
        XCTAssertEqual(dataRow[1], "pass,word", "Comma inside quotes must be part of the field")
        XCTAssertEqual(dataRow[2], "He said \"hello\"", "Escaped quotes must be unescaped")
    }

    // MARK: - Empty CSV

    func testCSVEmptyFile() {
        let entries = ImportService.parseBitwardenCSV("")
        XCTAssertTrue(entries.isEmpty, "Empty CSV must produce no entries")
    }

    // MARK: - Deduplication

    func testDeduplicateSkip() {
        let existing = [makeEntry(title: "Twitter", username: "john")]
        let imported = [makeEntry(title: "Twitter", username: "john"),
                        makeEntry(title: "GitHub", username: "dev")]

        let result = ImportService.deduplicate(imported: imported, existing: existing, strategy: .skip)

        XCTAssertEqual(result.entries.count, 1, "Duplicate must be skipped")
        XCTAssertEqual(result.entries[0].title, "GitHub")
        XCTAssertEqual(result.duplicateCount, 1)
        XCTAssertEqual(result.skippedCount, 1)
    }

    func testDeduplicateKeepBoth() {
        let existing = [makeEntry(title: "Twitter", username: "john")]
        let imported = [makeEntry(title: "Twitter", username: "john"),
                        makeEntry(title: "GitHub", username: "dev")]

        let result = ImportService.deduplicate(imported: imported, existing: existing, strategy: .keepBoth)

        XCTAssertEqual(result.entries.count, 2, "keepBoth must keep all entries")
        XCTAssertEqual(result.duplicateCount, 1)
        XCTAssertEqual(result.skippedCount, 0)
    }

    // MARK: - Bitwarden Category Mapping

    func testBitwardenCategoryMapping() {
        let csv = """
        folder,favorite,type,name,notes,fields,login_uri,login_username,login_password,login_totp
        ,0,card,Visa,,,,,,
        ,0,securenote,Secret Note,,,,,,
        ,0,identity,My ID,,,,,,
        ,0,login,Website,,,,user,pass,
        """

        let entries = ImportService.parseBitwardenCSV(csv)
        XCTAssertEqual(entries.count, 4)

        XCTAssertEqual(entries[0].category, .creditCard, "type 'card' must map to .creditCard")
        XCTAssertEqual(entries[1].category, .secureNote, "type 'securenote' must map to .secureNote")
        XCTAssertEqual(entries[2].category, .identity, "type 'identity' must map to .identity")
        XCTAssertEqual(entries[3].category, .login, "type 'login' must map to .login")
    }

    // MARK: - Helpers

    private func makeEntry(title: String, username: String) -> VaultEntry {
        VaultEntry(title: title, username: username, password: "pass", website: "", notes: "")
    }
}
