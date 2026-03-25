import Foundation
import CryptoKit

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
