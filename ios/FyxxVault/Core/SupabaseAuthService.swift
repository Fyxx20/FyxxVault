import Foundation
import Combine

/// Lightweight Supabase Auth client using direct REST API calls.
/// Handles sign-up, sign-in, sign-out, and session persistence.
/// The anon key is a PUBLIC key — Row Level Security protects the data.
@MainActor
final class SupabaseAuthService: ObservableObject {
    static let shared = SupabaseAuthService()

    private let baseURL = SupabaseConfig.url
    private let anonKey = SupabaseConfig.anonKey

    @Published var accessToken: String?
    @Published var userId: String?
    @Published var isAuthenticated = false

    private static let tokenKeychainKey = "fyxxvault.supabase.auth.token"
    private static let userIdKeychainKey = "fyxxvault.supabase.auth.userid"

    // MARK: - Sign Up

    func signUp(email: String, password: String) async throws {
        let url = URL(string: "\(baseURL)/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.networkError
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            // Extract access token from session (present when email confirmation is disabled)
            if let session = json?["session"] as? [String: Any],
               let token = session["access_token"] as? String {
                self.accessToken = token
                if let user = json?["user"] as? [String: Any],
                   let id = user["id"] as? String {
                    self.userId = id
                }
                self.isAuthenticated = true
                persistSession()
            } else if let user = json?["user"] as? [String: Any],
                      let id = user["id"] as? String {
                // Email confirmation required — user created but no session yet
                self.userId = id
            }
        } else if httpResponse.statusCode == 422 || httpResponse.statusCode == 400 {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = errorJson?["msg"] as? String
                ?? errorJson?["error_description"] as? String
                ?? "Un compte existe deja avec cet email."
            if msg.lowercased().contains("already") || msg.lowercased().contains("existe") {
                throw AuthServiceError.accountAlreadyExists
            }
            throw AuthServiceError.serverError(msg)
        } else {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = errorJson?["msg"] as? String
                ?? errorJson?["error_description"] as? String
                ?? "Erreur d'inscription"
            throw AuthServiceError.serverError(msg)
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.networkError
        }

        if httpResponse.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let token = json?["access_token"] as? String {
                self.accessToken = token
                if let user = json?["user"] as? [String: Any],
                   let id = user["id"] as? String {
                    self.userId = id
                }
                self.isAuthenticated = true
                persistSession()
            }
        } else if httpResponse.statusCode == 400 {
            throw AuthServiceError.invalidCredentials
        } else {
            throw AuthServiceError.invalidCredentials
        }
    }

    // MARK: - Sign Out

    func signOut() {
        accessToken = nil
        userId = nil
        isAuthenticated = false
        clearPersistedSession()
    }

    // MARK: - Restore Session

    /// Attempts to restore a previously saved session by verifying the token with Supabase.
    /// On network failure, keeps the token optimistically for offline use.
    func restoreSession() async {
        guard let tokenData = KeychainService.loadOptionalData(for: Self.tokenKeychainKey),
              let token = String(data: tokenData, encoding: .utf8),
              !token.isEmpty else { return }

        // Verify the token is still valid
        let url = URL(string: "\(baseURL)/auth/v1/user")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                self.accessToken = token
                self.userId = json?["id"] as? String
                self.isAuthenticated = true
            } else {
                // Token expired or invalid — clear it
                clearPersistedSession()
            }
        } catch {
            // Network error (offline) — keep the token optimistically
            self.accessToken = token
            if let uidData = KeychainService.loadOptionalData(for: Self.userIdKeychainKey),
               let uid = String(data: uidData, encoding: .utf8) {
                self.userId = uid
            }
            self.isAuthenticated = true
        }
    }

    // MARK: - Session Persistence

    private func persistSession() {
        if let token = accessToken {
            try? KeychainService.save(data: Data(token.utf8), key: Self.tokenKeychainKey)
        }
        if let uid = userId {
            try? KeychainService.save(data: Data(uid.utf8), key: Self.userIdKeychainKey)
        }
    }

    private func clearPersistedSession() {
        KeychainService.delete(key: Self.tokenKeychainKey)
        KeychainService.delete(key: Self.userIdKeychainKey)
    }

    // MARK: - Errors

    enum AuthServiceError: LocalizedError {
        case networkError
        case invalidCredentials
        case accountAlreadyExists
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .networkError:
                return "Erreur reseau. Verifie ta connexion."
            case .invalidCredentials:
                return "Email ou mot de passe incorrect."
            case .accountAlreadyExists:
                return "Un compte existe deja avec cet email."
            case .serverError(let msg):
                return msg
            }
        }
    }
}
