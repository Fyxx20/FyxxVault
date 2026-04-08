import Foundation
import Combine
import SwiftUI

// MARK: - Announcements Service

@MainActor
final class AnnouncementsService: ObservableObject {
    @Published var announcements: [FVAnnouncement] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false

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

    func fetch() async {
        isLoading = true
        defer { isLoading = false }
        await fetchSilently()
    }

    private func fetchSilently() async {
        guard let token = await validToken() else { return }
        do {
            let url = URL(string: baseURL + "/rest/v1/announcements?select=*&active=eq.true&order=created_at.desc")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 { return }
            let json = try JSONSerialization.jsonObject(with: data)
            if let items = json as? [[String: Any]] {
                let newAnnouncements = items.compactMap { FVAnnouncement(from: $0) }
                if newAnnouncements.map(\.id) != announcements.map(\.id) {
                    announcements = newAnnouncements
                }
                updateUnreadCount()
            }
        } catch {}
    }

    // MARK: - Polling (every 30s)

    func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
                guard !Task.isCancelled else { break }
                await self?.fetchSilently()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func markRead(_ id: String) {
        UserDefaults.standard.set(true, forKey: "fv.announcement.read.\(id)")
        updateUnreadCount()
    }

    func markAllRead() {
        for a in announcements { markRead(a.id) }
    }

    private func updateUnreadCount() {
        unreadCount = announcements.filter { !$0.isRead }.count
    }
}
