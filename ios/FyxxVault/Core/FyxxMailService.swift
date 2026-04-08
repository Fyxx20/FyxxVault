import Foundation
import Combine
import SwiftUI

// MARK: - FyxxMail Service (Supabase-based email aliases + inbox)

@MainActor
final class FyxxMailService: ObservableObject {
    @Published var aliases: [FyxxEmailAlias] = []
    @Published var emails: [FyxxEmail] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    @Published var error: String?

    private let baseURL = SupabaseConfig.url
    private let anonKey = SupabaseConfig.anonKey

    /// Reference to SyncService for token refresh
    weak var syncService: SyncService?

    /// Get a valid (non-expired) access token, refreshing if needed
    private func validToken() async -> String? {
        if let sync = syncService {
            return await sync.getValidAccessToken()
        }
        // Fallback: read from keychain without refresh
        guard let data = KeychainService.loadOptionalData(for: "fyxxvault.cloud.access.token"),
              let token = String(data: data, encoding: .utf8) else { return nil }
        return token
    }

    /// Extract user_id (sub claim) from a JWT
    private func userId(from token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
        while base64.count % 4 != 0 { base64.append("=") }
        guard let payloadData = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let sub = json["sub"] as? String else { return nil }
        return sub
    }

    var isAuthenticated: Bool {
        KeychainService.loadOptionalData(for: "fyxxvault.cloud.access.token") != nil
    }

    // MARK: - Real-time Polling

    private var pollTask: Task<Void, Never>?
    private var currentFolder: String = "inbox"

    /// Start polling aliases + emails every 5 seconds
    func startPolling(folder: String = "inbox") {
        currentFolder = folder
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
                guard !Task.isCancelled else { break }
                await self?.refreshSilently()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Refresh without showing loading indicator (background sync)
    private func refreshSilently() async {
        guard let token = await validToken() else { return }
        // Fetch aliases
        if let data = try? await getJSON(path: "/rest/v1/email_aliases?select=*&order=created_at.desc", token: token),
           let items = data as? [[String: Any]] {
            let newAliases = items.compactMap { FyxxEmailAlias(from: $0) }
            if newAliases != aliases { aliases = newAliases }
        }
        // Fetch emails for current folder
        let path = "/rest/v1/emails?select=*&folder=eq.\(currentFolder)&order=received_at.desc&limit=50"
        if let data = try? await getJSON(path: path, token: token),
           let items = data as? [[String: Any]] {
            let newEmails = items.compactMap { FyxxEmail(from: $0) }
            if newEmails != emails {
                emails = newEmails
                updateUnreadCount()
            }
        }
    }

    /// Update folder being polled
    func updatePollingFolder(_ folder: String) {
        currentFolder = folder
    }

    // MARK: - Aliases

    func fetchAliases() async {
        guard let token = await validToken() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await getJSON(path: "/rest/v1/email_aliases?select=*&order=created_at.desc", token: token)
            if let items = data as? [[String: Any]] {
                aliases = items.compactMap { FyxxEmailAlias(from: $0) }
            }
        } catch {
            self.error = "Aliases: \(error.localizedDescription)"
            print("[FyxxMail] fetchAliases error: \(error)")
        }
    }

    func createAlias(label: String) async -> Bool {
        guard let token = await validToken(),
              let userId = userId(from: token) else {
            self.error = "Utilisateur non authentifié"
            return false
        }
        guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        isLoading = true
        defer { isLoading = false }
        let slug = label.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let suffix = String(UUID().uuidString.prefix(6).lowercased())
        let address = "\(slug)-\(suffix)@fyxxmail.com"
        let body: [String: Any] = [
            "user_id": userId,
            "address": address,
            "label": label,
            "is_active": true
        ]
        do {
            _ = try await postJSON(path: "/rest/v1/email_aliases", body: body, token: token)
            await fetchAliases()
            return true
        } catch {
            self.error = "Création alias: \(error.localizedDescription)"
            print("[FyxxMail] createAlias error: \(error)")
            return false
        }
    }

    func toggleAlias(id: String, active: Bool) async {
        guard let token = await validToken() else { return }
        do {
            _ = try await patchJSON(path: "/rest/v1/email_aliases?id=eq.\(id)", body: ["is_active": active], token: token)
            if let idx = aliases.firstIndex(where: { $0.id == id }) {
                aliases[idx].isActive = active
            }
        } catch {
            self.error = error.localizedDescription
            print("[FyxxMail] toggleAlias error: \(error)")
        }
    }

    func deleteAlias(id: String) async {
        guard let token = await validToken() else { return }
        do {
            try await deleteJSON(path: "/rest/v1/email_aliases?id=eq.\(id)", token: token)
            aliases.removeAll { $0.id == id }
            emails.removeAll { $0.aliasId == id }
            updateUnreadCount()
        } catch {
            self.error = error.localizedDescription
            print("[FyxxMail] deleteAlias error: \(error)")
        }
    }

    // MARK: - Emails

    func fetchEmails(aliasId: String? = nil, folder: String = "inbox") async {
        guard let token = await validToken() else { return }
        isLoading = true
        defer { isLoading = false }
        var path = "/rest/v1/emails?select=*&folder=eq.\(folder)&order=received_at.desc&limit=50"
        if let aliasId { path += "&alias_id=eq.\(aliasId)" }
        do {
            let data = try await getJSON(path: path, token: token)
            if let items = data as? [[String: Any]] {
                emails = items.compactMap { FyxxEmail(from: $0) }
                updateUnreadCount()
            }
        } catch {
            self.error = error.localizedDescription
            print("[FyxxMail] fetchEmails error: \(error)")
        }
    }

    func markAsRead(id: String) async {
        guard let token = await validToken() else { return }
        do {
            _ = try await patchJSON(path: "/rest/v1/emails?id=eq.\(id)", body: ["is_read": true], token: token)
            if let idx = emails.firstIndex(where: { $0.id == id }) {
                emails[idx].isRead = true
                updateUnreadCount()
            }
        } catch {
            print("[FyxxMail] markAsRead error: \(error)")
        }
    }

    func toggleStarred(id: String) async {
        guard let idx = emails.firstIndex(where: { $0.id == id }) else { return }
        let newValue = !emails[idx].isStarred
        guard let token = await validToken() else { return }
        do {
            _ = try await patchJSON(path: "/rest/v1/emails?id=eq.\(id)", body: ["is_starred": newValue], token: token)
            emails[idx].isStarred = newValue
        } catch {
            print("[FyxxMail] toggleStarred error: \(error)")
        }
    }

    func moveToFolder(id: String, folder: String) async {
        guard let token = await validToken() else { return }
        do {
            _ = try await patchJSON(path: "/rest/v1/emails?id=eq.\(id)", body: ["folder": folder], token: token)
            emails.removeAll { $0.id == id }
            updateUnreadCount()
        } catch {
            print("[FyxxMail] moveToFolder error: \(error)")
        }
    }

    func deleteEmail(id: String) async {
        guard let token = await validToken() else { return }
        do {
            try await deleteJSON(path: "/rest/v1/emails?id=eq.\(id)", token: token)
            emails.removeAll { $0.id == id }
            updateUnreadCount()
        } catch {
            print("[FyxxMail] deleteEmail error: \(error)")
        }
    }

    private func updateUnreadCount() {
        unreadCount = emails.filter { !$0.isRead && $0.folder == "inbox" }.count
    }

    // MARK: - REST Helpers

    private func getJSON(path: String, token: String) async throws -> Any {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            print("[FyxxMail] GET \(path) → \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func postJSON(path: String, body: [String: Any], token: String) async throws -> Any {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let errBody = String(data: data, encoding: .utf8) ?? "unknown"
            print("[FyxxMail] POST \(path) → \(http.statusCode): \(errBody)")
            throw URLError(.badServerResponse)
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func patchJSON(path: String, body: [String: Any], token: String) async throws -> Any {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let errBody = String(data: data, encoding: .utf8) ?? "unknown"
            print("[FyxxMail] PATCH \(path) → \(http.statusCode): \(errBody)")
            throw URLError(.badServerResponse)
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func deleteJSON(path: String, token: String) async throws {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let errBody = String(data: data, encoding: .utf8) ?? "unknown"
            print("[FyxxMail] DELETE \(path) → \(http.statusCode): \(errBody)")
            throw URLError(.badServerResponse)
        }
    }
}
