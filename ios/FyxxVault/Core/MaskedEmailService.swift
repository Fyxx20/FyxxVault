import Foundation
import SwiftUI
import Combine

struct MaskedEmail: Codable, Identifiable, Hashable {
    var id: String
    var email: String
    var description: String
    var forwardTo: String
    var isActive: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email, description
        case forwardTo = "forward_to"
        case isActive = "active"
        case createdAt = "created_at"
    }
}

@MainActor
final class MaskedEmailService: ObservableObject {
    @Published var aliases: [MaskedEmail] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isConfigured: Bool = false

    private var apiToken: String?
    private let baseURL = "https://app.addy.io/api/v1"

    init() {
        if let tokenData = KeychainService.loadOptionalData(for: "fyxxvault.addy.api.token"),
           let token = String(data: tokenData, encoding: .utf8), !token.isEmpty {
            apiToken = token
            isConfigured = true
        }
    }

    // MARK: - Configuration

    func configure(apiToken: String) {
        self.apiToken = apiToken
        self.isConfigured = true
        try? KeychainService.save(data: Data(apiToken.utf8), key: "fyxxvault.addy.api.token")
    }

    func disconnect() {
        apiToken = nil
        isConfigured = false
        aliases = []
        KeychainService.delete(key: "fyxxvault.addy.api.token")
    }

    // MARK: - API Operations

    func fetchAliases() async {
        guard let token = apiToken else { return }
        isLoading = true
        error = nil

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/aliases")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                error = "Erreur lors de la récupération des alias"
                isLoading = false
                return
            }

            struct AliasResponse: Codable {
                struct AliasData: Codable {
                    let id: String
                    let email: String
                    let description: String?
                    let active: Bool
                    let created_at: String
                }
                let data: [AliasData]
            }

            let decoded = try JSONDecoder().decode(AliasResponse.self, from: data)
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            aliases = decoded.data.map { alias in
                MaskedEmail(
                    id: alias.id,
                    email: alias.email,
                    description: alias.description ?? "",
                    forwardTo: "",
                    isActive: alias.active,
                    createdAt: dateFormatter.date(from: alias.created_at) ?? Date()
                )
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func createAlias(description: String, domain: String? = nil) async -> MaskedEmail? {
        guard let token = apiToken else { return nil }
        isLoading = true
        error = nil

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/aliases")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            var body: [String: Any] = ["description": description]
            if let domain { body["domain"] = domain }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                self.error = "Erreur: \(errorMsg)"
                isLoading = false
                return nil
            }

            struct CreateResponse: Codable {
                struct AliasData: Codable {
                    let id: String
                    let email: String
                    let description: String?
                    let active: Bool
                    let created_at: String
                }
                let data: AliasData
            }

            let decoded = try JSONDecoder().decode(CreateResponse.self, from: data)
            let alias = MaskedEmail(
                id: decoded.data.id,
                email: decoded.data.email,
                description: decoded.data.description ?? description,
                forwardTo: "",
                isActive: decoded.data.active,
                createdAt: Date()
            )
            aliases.insert(alias, at: 0)
            isLoading = false
            return alias
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return nil
        }
    }

    func toggleAlias(id: String, active: Bool) async {
        guard let token = apiToken else { return }

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/active-aliases")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = ["id": id]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (_, _) = try await URLSession.shared.data(for: request)

            if let idx = aliases.firstIndex(where: { $0.id == id }) {
                aliases[idx].isActive = active
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteAlias(id: String) async {
        guard let token = apiToken else { return }

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/aliases/\(id)")!)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (_, _) = try await URLSession.shared.data(for: request)
            aliases.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
