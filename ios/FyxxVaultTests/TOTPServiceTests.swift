import XCTest
@testable import FyxxVault

final class TOTPServiceTests: XCTestCase {

    // Base32("Hello!") == "JBSWY3DPEHPK3PXP"
    private let knownSecret = "JBSWY3DPEHPK3PXP"

    // MARK: - Known TOTP Vector

    func testKnownTOTPVector() {
        // Use a fixed epoch timestamp and verify deterministic output
        let date = Date(timeIntervalSince1970: 1_234_567_890) // 2009-02-13 23:31:30 UTC

        let snapshot = TOTPService.snapshot(secretInput: knownSecret, at: date)
        XCTAssertNotNil(snapshot, "Snapshot must not be nil for a valid secret")

        let code = snapshot!.code
        XCTAssertEqual(code.count, 6, "Code must be 6 digits")
        XCTAssertTrue(code.allSatisfy(\.isNumber), "Code must consist only of digits")

        // Verify determinism: same inputs produce same code
        let snapshot2 = TOTPService.snapshot(secretInput: knownSecret, at: date)
        XCTAssertEqual(snapshot2?.code, code, "Same secret and time must produce the same code")
    }

    // MARK: - Snapshot Returns Code

    func testSnapshotReturnsCode() {
        let snapshot = TOTPService.snapshot(secretInput: knownSecret)
        XCTAssertNotNil(snapshot, "Snapshot must not be nil for a valid base32 secret")
        XCTAssertEqual(snapshot!.code.count, 6, "Default TOTP code must be 6 digits")
    }

    // MARK: - Remaining Seconds

    func testSnapshotRemainingSeconds() {
        let snapshot = TOTPService.snapshot(secretInput: knownSecret)
        XCTAssertNotNil(snapshot)
        XCTAssertGreaterThan(snapshot!.remainingSeconds, 0, "Remaining seconds must be > 0")
        XCTAssertLessThanOrEqual(snapshot!.remainingSeconds, 30, "Remaining seconds must be <= 30")
    }

    func testRemainingSecondsRangeMultipleTimestamps() {
        // Test 100 different timestamps to cover the full period
        for i in 0..<100 {
            let date = Date(timeIntervalSince1970: Double(1_700_000_000 + i))
            if let snapshot = TOTPService.snapshot(secretInput: knownSecret, at: date) {
                XCTAssertGreaterThan(snapshot.remainingSeconds, 0)
                XCTAssertLessThanOrEqual(snapshot.remainingSeconds, 30)
            }
        }
    }

    // MARK: - OTPAuth URL Parsing

    func testOTPAuthURLParsing() {
        let url = "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&digits=6&period=30"
        let date = Date(timeIntervalSince1970: 1_000_000_000)

        let fromURL = TOTPService.snapshot(secretInput: url, at: date)
        let fromRaw = TOTPService.snapshot(secretInput: knownSecret, at: date)

        XCTAssertNotNil(fromURL, "OTPAuth URL must parse successfully")
        XCTAssertNotNil(fromRaw)
        XCTAssertEqual(fromURL?.code, fromRaw?.code,
                       "OTPAuth URL and raw secret must produce the same code")
    }

    func testOTPAuthURIWithIssuer() {
        let uri = "otpauth://totp/GitHub:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&digits=6&period=30"
        let snapshot = TOTPService.snapshot(secretInput: uri, at: Date())
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.code.count, 6)
    }

    func testOTPAuthURIWith8Digits() {
        let uri = "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&digits=8"
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = TOTPService.snapshot(secretInput: uri, at: fixedDate)
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.code.count, 8, "8-digit OTP must produce 8 digit code")
    }

    func testOTPAuthURIWithCustomPeriod() {
        let uri = "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&period=60"
        let snapshot = TOTPService.snapshot(secretInput: uri, at: Date())
        XCTAssertNotNil(snapshot)
        XCTAssertTrue(snapshot!.remainingSeconds <= 60)
    }

    // MARK: - Invalid Secret

    func testInvalidSecretReturnsNil() {
        XCTAssertNil(TOTPService.snapshot(secretInput: ""), "Empty secret must return nil")
        XCTAssertNil(TOTPService.snapshot(secretInput: "   "), "Whitespace-only secret must return nil")
        XCTAssertNil(TOTPService.snapshot(secretInput: "!!!???"), "Non-base32 characters must return nil")
        XCTAssertNil(TOTPService.snapshot(secretInput: "111111"), "'1' is not in base32 alphabet")
    }

    func testOTPAuthWithEmptySecretReturnsNil() {
        let uri = "otpauth://totp/Test?secret=&digits=6"
        XCTAssertNil(TOTPService.snapshot(secretInput: uri))
    }

    // MARK: - Different Times Produce Different Codes

    func testDifferentTimesProduceDifferentCodes() {
        let t1 = Date(timeIntervalSince1970: 0)
        let t2 = Date(timeIntervalSince1970: 30)

        let code1 = TOTPService.snapshot(secretInput: knownSecret, at: t1)?.code
        let code2 = TOTPService.snapshot(secretInput: knownSecret, at: t2)?.code

        XCTAssertNotNil(code1)
        XCTAssertNotNil(code2)
        // While there is a tiny chance of collision (1/1,000,000), these specific timestamps differ
        XCTAssertNotEqual(code1, code2,
                          "Codes at t=0 and t=30 should differ (different TOTP windows)")
    }

    // MARK: - Base32 Formatting Tolerance

    func testBase32WithSpacesAndDashes() {
        let secretSpaces = "JBSW Y3DP EHPK 3PXP"
        let secretDashes = "JBSW-Y3DP-EHPK-3PXP"
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

        let code1 = TOTPService.snapshot(secretInput: knownSecret, at: fixedDate)?.code
        let code2 = TOTPService.snapshot(secretInput: secretSpaces, at: fixedDate)?.code
        let code3 = TOTPService.snapshot(secretInput: secretDashes, at: fixedDate)?.code

        XCTAssertNotNil(code1)
        XCTAssertEqual(code1, code2, "Spaces in secret must be ignored")
        XCTAssertEqual(code1, code3, "Dashes in secret must be ignored")
    }

    func testBase32CaseInsensitive() {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

        let upper = TOTPService.snapshot(secretInput: "JBSWY3DPEHPK3PXP", at: fixedDate)?.code
        let lower = TOTPService.snapshot(secretInput: "jbswy3dpehpk3pxp", at: fixedDate)?.code

        XCTAssertNotNil(upper)
        XCTAssertEqual(upper, lower, "Base32 decoding must be case-insensitive")
    }
}
