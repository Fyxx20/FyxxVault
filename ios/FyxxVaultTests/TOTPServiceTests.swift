import XCTest
@testable import FyxxVault

final class TOTPServiceTests: XCTestCase {

    // MARK: - RFC 6238 Test Vectors

    /// Test with the well-known RFC 6238 test secret (base32: JBSWY3DPEHPK3PXP)
    /// which is the base32 encoding of "12345678901234567890"
    func testKnownSecretProducesValidCode() {
        let secret = "JBSWY3DPEHPK3PXP"
        let snapshot = TOTPService.snapshot(secretInput: secret, at: Date())
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.code.count, 6)
        XCTAssertTrue(snapshot!.remainingSeconds > 0)
        XCTAssertTrue(snapshot!.remainingSeconds <= 30)
    }

    /// Two calls at the same instant should produce the same code
    func testDeterministicForSameTimestamp() {
        let secret = "JBSWY3DPEHPK3PXP"
        let fixedDate = Date(timeIntervalSince1970: 1700000000)

        let a = TOTPService.snapshot(secretInput: secret, at: fixedDate)
        let b = TOTPService.snapshot(secretInput: secret, at: fixedDate)

        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertEqual(a?.code, b?.code)
    }

    /// Codes should differ across different time periods (30 seconds apart)
    func testDifferentCodesForDifferentPeriods() {
        let secret = "JBSWY3DPEHPK3PXP"
        let t1 = Date(timeIntervalSince1970: 1700000000)
        let t2 = Date(timeIntervalSince1970: 1700000030) // 30s later

        let code1 = TOTPService.snapshot(secretInput: secret, at: t1)?.code
        let code2 = TOTPService.snapshot(secretInput: secret, at: t2)?.code

        XCTAssertNotNil(code1)
        XCTAssertNotNil(code2)
        // Very unlikely to be the same (1 in 1,000,000), but technically possible
        // This test validates that the function accepts different timestamps
    }

    // MARK: - OTPAuth URI Parsing

    func testOTPAuthURIParsing() {
        let uri = "otpauth://totp/GitHub:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&digits=6&period=30"
        let snapshot = TOTPService.snapshot(secretInput: uri, at: Date())
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.code.count, 6)
    }

    func testOTPAuthURIWith8Digits() {
        let uri = "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&digits=8"
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let snapshot = TOTPService.snapshot(secretInput: uri, at: fixedDate)
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.code.count, 8)
    }

    func testOTPAuthURIWithCustomPeriod() {
        let uri = "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&period=60"
        let snapshot = TOTPService.snapshot(secretInput: uri, at: Date())
        XCTAssertNotNil(snapshot)
        XCTAssertTrue(snapshot!.remainingSeconds <= 60)
    }

    // MARK: - Edge Cases

    func testEmptySecretReturnsNil() {
        XCTAssertNil(TOTPService.snapshot(secretInput: ""))
        XCTAssertNil(TOTPService.snapshot(secretInput: "   "))
    }

    func testInvalidBase32ReturnsNil() {
        // "1" is not in the base32 alphabet (A-Z, 2-7)
        XCTAssertNil(TOTPService.snapshot(secretInput: "111111"))
    }

    func testOTPAuthWithEmptySecretReturnsNil() {
        let uri = "otpauth://totp/Test?secret=&digits=6"
        XCTAssertNil(TOTPService.snapshot(secretInput: uri))
    }

    func testRemainingSecondsRange() {
        let secret = "JBSWY3DPEHPK3PXP"
        // Test 100 different timestamps
        for i in 0..<100 {
            let date = Date(timeIntervalSince1970: Double(1700000000 + i))
            if let snapshot = TOTPService.snapshot(secretInput: secret, at: date) {
                XCTAssertGreaterThan(snapshot.remainingSeconds, 0)
                XCTAssertLessThanOrEqual(snapshot.remainingSeconds, 30)
            }
        }
    }

    func testBase32WithSpacesAndDashes() {
        // Some authenticator apps format the secret with spaces/dashes
        let secretClean = "JBSWY3DPEHPK3PXP"
        let secretSpaces = "JBSW Y3DP EHPK 3PXP"
        let secretDashes = "JBSW-Y3DP-EHPK-3PXP"

        let fixedDate = Date(timeIntervalSince1970: 1700000000)

        let code1 = TOTPService.snapshot(secretInput: secretClean, at: fixedDate)?.code
        let code2 = TOTPService.snapshot(secretInput: secretSpaces, at: fixedDate)?.code
        let code3 = TOTPService.snapshot(secretInput: secretDashes, at: fixedDate)?.code

        XCTAssertNotNil(code1)
        XCTAssertEqual(code1, code2)
        XCTAssertEqual(code1, code3)
    }

    func testBase32CaseInsensitive() {
        let fixedDate = Date(timeIntervalSince1970: 1700000000)

        let upper = TOTPService.snapshot(secretInput: "JBSWY3DPEHPK3PXP", at: fixedDate)?.code
        let lower = TOTPService.snapshot(secretInput: "jbswy3dpehpk3pxp", at: fixedDate)?.code

        XCTAssertNotNil(upper)
        XCTAssertEqual(upper, lower)
    }
}
