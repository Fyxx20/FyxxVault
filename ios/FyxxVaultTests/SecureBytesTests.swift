import XCTest
@testable import FyxxVault

final class SecureBytesTests: XCTestCase {

    func testInitFromString() {
        let secure = SecureBytes("hello")
        XCTAssertEqual(secure.count, 5)
        XCTAssertFalse(secure.isEmpty)
        XCTAssertEqual(secure.toString(), "hello")
    }

    func testInitFromData() {
        let data = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F]) // "Hello"
        let secure = SecureBytes(data)
        XCTAssertEqual(secure.count, 5)
        XCTAssertEqual(secure.toData(), data)
    }

    func testInitEmptyCount() {
        let secure = SecureBytes(count: 32)
        XCTAssertEqual(secure.count, 32)
        // All bytes should be zero
        let data = secure.toData()
        XCTAssertTrue(data.allSatisfy { $0 == 0 })
    }

    func testWipeClearsContent() {
        let secure = SecureBytes("sensitive password")
        XCTAssertFalse(secure.isEmpty)

        secure.wipe()

        XCTAssertTrue(secure.isEmpty)
        XCTAssertEqual(secure.count, 0)
    }

    func testToDataReturnsCopy() {
        let secure = SecureBytes("test")
        let data = secure.toData()
        secure.wipe()

        // The Data copy should still be intact even after wiping
        XCTAssertEqual(data, Data("test".utf8))
    }

    func testWithUnsafeBytes() {
        let secure = SecureBytes("abc")
        var bytesRead: [UInt8] = []

        secure.withUnsafeBytes { buffer in
            bytesRead = Array(buffer)
        }

        XCTAssertEqual(bytesRead, [0x61, 0x62, 0x63]) // "abc"
    }

    func testDeinitWipesMemory() {
        // We can't directly test deinit wipes memory, but we can verify
        // that creating and destroying SecureBytes doesn't crash
        for _ in 0..<1000 {
            let _ = SecureBytes("password_that_should_be_wiped")
        }
        // If we got here without crashing, the deinit path works
    }
}
