import Foundation
import Combine
import SwiftUI

// MARK: - Support Service (tickets + chat)

@MainActor
final class SupportService: ObservableObject {
    @Published var tickets: [SupportTicket] = []
    @Published var messages: [SupportMessage] = []
    @Published var currentTicket: SupportTicket?
    @Published var isLoading = false
    @Published var isSending = false
    @Published var error: String?
    @Published var unreadAdminMessages: Int = 0

    private let baseURL = SupabaseConfig.url
    private let anonKey = SupabaseConfig.anonKey
    private var pollTask: Task<Void, Never>?

    /// Reference to SyncService for token refresh
    weak var syncService: SyncService?

    private func validToken() async -> String? {
        if let sync = syncService {
            return await sync.getValidAccessToken()
        }
        guard let data = KeychainService.loadOptionalData(for: "fyxxvault.cloud.access.token"),
              let token = String(data: data, encoding: .utf8) else { return nil }
        return token
    }

    private func userId(from token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else { return nil }
        return sub
    }

    var isAuthenticated: Bool {
        KeychainService.loadOptionalData(for: "fyxxvault.cloud.access.token") != nil
    }

    // MARK: - Tickets

    func fetchTickets() async {
        guard let token = await validToken() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await getJSON(path: "/rest/v1/support_tickets?select=*&order=updated_at.desc", token: token)
            if let items = data as? [[String: Any]] {
                tickets = items.compactMap { SupportTicket(from: $0) }
            }
        } catch {
            self.error = error.localizedDescription
            print("[Support] fetchTickets error: \(error)")
        }
    }

    func createTicketFromArray(subject: String, firstMessage: String, userEmail: String) async -> String? {
        guard let token = await validToken(),
              let uid = userId(from: token) else {
            self.error = "Non authentifié"
            return nil
        }
        isSending = true
        defer { isSending = false }
        let ticketBody: [String: Any] = [
            "user_id": uid,
            "user_email": userEmail,
            "subject": subject,
            "status": "open"
        ]
        do {
            let resultData = try await postJSON(path: "/rest/v1/support_tickets", body: ticketBody, token: token)
            var ticketId: String?
            if let arr = resultData as? [[String: Any]], let first = arr.first {
                ticketId = first["id"] as? String
            } else if let dict = resultData as? [String: Any] {
                ticketId = dict["id"] as? String
            }
            guard let tid = ticketId else {
                print("[Support] createTicket: no ticket id in response")
                return nil
            }
            let msgBody: [String: Any] = [
                "ticket_id": tid,
                "sender_type": "user",
                "sender_name": userEmail,
                "content": firstMessage
            ]
            _ = try await postJSON(path: "/rest/v1/support_messages", body: msgBody, token: token)
            await fetchTickets()
            currentTicket = tickets.first(where: { $0.id == tid })
            return tid
        } catch {
            self.error = error.localizedDescription
            print("[Support] createTicket error: \(error)")
            return nil
        }
    }

    // MARK: - Messages

    func fetchMessages(ticketId: String) async {
        guard let token = await validToken() else { return }
        do {
            let data = try await getJSON(path: "/rest/v1/support_messages?ticket_id=eq.\(ticketId)&order=created_at.asc", token: token)
            if let items = data as? [[String: Any]] {
                messages = items.compactMap { SupportMessage(from: $0) }
                updateUnreadCount()
            }
        } catch {
            print("[Support] fetchMessages error: \(error)")
        }
    }

    func sendMessage(ticketId: String, content: String, userEmail: String) async {
        guard let token = await validToken() else { return }
        isSending = true
        defer { isSending = false }
        let body: [String: Any] = [
            "ticket_id": ticketId,
            "sender_type": "user",
            "sender_name": userEmail,
            "content": content
        ]
        do {
            _ = try await postJSON(path: "/rest/v1/support_messages", body: body, token: token)
            await fetchMessages(ticketId: ticketId)
        } catch {
            self.error = error.localizedDescription
            print("[Support] sendMessage error: \(error)")
        }
    }

    // MARK: - Polling

    private var ticketPollTask: Task<Void, Never>?

    func startPolling(ticketId: String) {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.fetchMessages(ticketId: ticketId)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Poll ticket list every 10s (for new tickets from admin, status changes)
    func startTicketListPolling() {
        stopTicketListPolling()
        ticketPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
                guard !Task.isCancelled else { break }
                await self?.fetchTickets()
            }
        }
    }

    func stopTicketListPolling() {
        ticketPollTask?.cancel()
        ticketPollTask = nil
    }

    private func updateUnreadCount() {
        let lastRead = UserDefaults.standard.integer(forKey: "fv.support.lastReadCount.\(currentTicket?.id ?? "")")
        let adminMsgs = messages.filter { $0.senderType == "admin" }.count
        unreadAdminMessages = max(0, adminMsgs - lastRead)
    }

    func markMessagesRead() {
        guard let id = currentTicket?.id else { return }
        let adminMsgs = messages.filter { $0.senderType == "admin" }.count
        UserDefaults.standard.set(adminMsgs, forKey: "fv.support.lastReadCount.\(id)")
        unreadAdminMessages = 0
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
            print("[Support] GET \(path) → \(http.statusCode): \(body)")
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
            print("[Support] POST \(path) → \(http.statusCode): \(errBody)")
            throw URLError(.badServerResponse)
        }
        return try JSONSerialization.jsonObject(with: data)
    }
}
