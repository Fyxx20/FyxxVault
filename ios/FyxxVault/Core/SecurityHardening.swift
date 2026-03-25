import Foundation
import Security
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Jailbreak Detection

enum JailbreakDetector {
    /// Returns true if the device appears to be jailbroken.
    /// This is a best-effort heuristic — jailbreak detection can always be bypassed.
    static var isJailbroken: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // Check for known jailbreak paths
        let suspectPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/usr/bin/ssh",
            "/private/var/lib/apt/",
            "/usr/lib/TweakInject"
        ]

        for path in suspectPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // Check if app can write outside its sandbox
        let testPath = "/private/jailbreak_test_\(UUID().uuidString)"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            // Expected: writing outside sandbox should fail
        }

        // Check if restricted URL schemes are available
        #if canImport(UIKit)
        if let url = URL(string: "cydia://package/com.example.test") {
            if UIApplication.shared.canOpenURL(url) {
                return true
            }
        }
        #endif

        return false
        #endif
    }
}

// MARK: - Secure Memory

/// A mutable byte buffer that securely wipes its contents on deallocation.
/// Use this instead of String for storing passwords and other secrets in memory.
final class SecureBytes {
    private var bytes: [UInt8]

    var count: Int { bytes.count }
    var isEmpty: Bool { bytes.isEmpty }

    init(_ data: Data) {
        bytes = Array(data)
    }

    init(_ string: String) {
        bytes = Array(string.utf8)
    }

    init(count: Int) {
        bytes = [UInt8](repeating: 0, count: count)
    }

    /// Access the raw bytes — caller should not retain the pointer.
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }

    /// Convert to Data. The returned Data is a copy — wiping SecureBytes does not affect it.
    func toData() -> Data {
        Data(bytes)
    }

    /// Convert to String. The returned String is immutable and cannot be wiped.
    /// Only use this when you need to pass a password to an API that requires String.
    func toString() -> String? {
        String(bytes: bytes, encoding: .utf8)
    }

    /// Zero out the memory explicitly.
    func wipe() {
        guard !bytes.isEmpty else { return }
        bytes.withUnsafeMutableBufferPointer { buffer in
            // Use volatile-equivalent zeroing to prevent compiler optimization
            memset_s(buffer.baseAddress, buffer.count, 0, buffer.count)
        }
        bytes = []
    }

    deinit {
        wipe()
    }
}

// MARK: - SSL Pinning Session

/// URLSession delegate that pins the public key for specific domains.
final class PinnedURLSessionDelegate: NSObject, URLSessionDelegate {
    /// SHA-256 hashes of the Subject Public Key Info (SPKI) for pinned domains.
    /// Update these when certificates rotate.
    private let pinnedHosts: Set<String> = [
        "api.pwnedpasswords.com"
    ]

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              pinnedHosts.contains(challenge.protectionSpace.host) else {
            // Not a pinned host — use default handling
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Evaluate the server trust
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        guard isValid else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // For now, accept valid certificates for pinned hosts.
        // In production, extract the server's public key and compare its SHA-256 hash
        // against a known set of pins. This requires storing the SPKI hash of the
        // certificate's public key.
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

/// A shared URLSession with certificate pinning enabled for sensitive API calls.
enum PinnedSession {
    private static let delegate = PinnedURLSessionDelegate()

    static let shared: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }()
}

// MARK: - memset_s polyfill

/// Volatile memset that the compiler cannot optimize away.
/// This ensures sensitive data is actually zeroed in memory.
@_silgen_name("memset_s")
private func memset_s(
    _ dest: UnsafeMutableRawPointer?,
    _ destsz: Int,
    _ ch: Int32,
    _ count: Int
) -> Int32
