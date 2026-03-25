import Foundation
import CryptoKit

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
