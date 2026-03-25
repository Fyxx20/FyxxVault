import Foundation
import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Sync Types

enum SyncState: Equatable {
    case idle
    case syncing
    case error(String)
    case disabled

    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.disabled, .disabled): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

enum SyncError: LocalizedError {
    case notAuthenticated
    case notUnlocked
    case networkError(Error)
    case encryptionError(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Non connecté au cloud"
        case .notUnlocked: return "Coffre cloud verrouillé"
        case .networkError(let e): return "Erreur réseau: \(e.localizedDescription)"
        case .encryptionError(let msg): return "Erreur chiffrement: \(msg)"
        case .serverError(let msg): return "Erreur serveur: \(msg)"
        }
    }
}

// MARK: - Supabase Data Models

struct CloudProfile: Codable {
    let id: String
    let createdAt: String?
    let wrappedVek: String  // Base64 encoded
    let vekSalt: String     // Base64 encoded
    let vekRounds: Int

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case wrappedVek = "wrapped_vek"
        case vekSalt = "vek_salt"
        case vekRounds = "vek_rounds"
    }
}

struct CloudVaultItem: Codable {
    let id: String
    let userId: String
    let encryptedBlob: String  // Base64 encoded
    let updatedAt: String
    let deletedAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case encryptedBlob = "encrypted_blob"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
    }
}

// MARK: - Sync Service

@MainActor
final class SyncService: ObservableObject {
    @Published var state: SyncState = .disabled
    @Published var lastSyncDate: Date?
    @Published var isCloudAuthenticated = false
    @Published var cloudEmail: String?

    /// Vault Encryption Key — in-memory only, NEVER persisted
    private var vek: Data?
    private let deviceID: String

    // Supabase REST API helpers (no SDK dependency needed)
    private let baseURL: String
    private let anonKey: String
    private var accessToken: String?
    private var refreshToken: String?

    init() {
        self.deviceID = Self.getOrCreateDeviceID()
        self.baseURL = SupabaseConfig.url
        self.anonKey = SupabaseConfig.anonKey

        // Check for saved session
        loadSession()
    }

    // MARK: - Auth

    func signUpWithEmail(email: String, password: String, masterPassword: String) async throws {
        // 1. Create Supabase auth account
        let authBody: [String: Any] = ["email": email, "password": password]
        let authData = try await postJSON(path: "/auth/v1/signup", body: authBody, auth: false)

        guard let userId = authData["id"] as? String else {
            // Check if nested in "user" object
            if let user = authData["user"] as? [String: Any], let uid = user["id"] as? String {
                try await setupCloudKeys(userId: uid, masterPassword: masterPassword, authData: authData)
                return
            }
            throw SyncError.serverError("Inscription échouée")
        }

        try await setupCloudKeys(userId: userId, masterPassword: masterPassword, authData: authData)
    }

    private func setupCloudKeys(userId: String, masterPassword: String, authData: [String: Any]) async throws {
        // Extract tokens
        if let token = authData["access_token"] as? String {
            accessToken = token
            refreshToken = authData["refresh_token"] as? String
            saveSession()
        }

        // 2. Generate VEK
        let newVEK = CloudKeyManager.generateVEK()

        // 3. Derive KEK from master password
        let salt = CryptoService.makeSalt()
        let kek = CloudKeyManager.deriveKEK(masterPassword: masterPassword, salt: salt)

        // 4. Wrap VEK with KEK
        let wrappedVEK = try CloudKeyManager.wrapVEK(newVEK, with: kek)

        // 5. Store in profiles table
        let profileBody: [String: Any] = [
            "id": userId,
            "wrapped_vek": wrappedVEK.base64EncodedString(),
            "vek_salt": salt.base64EncodedString(),
            "vek_rounds": 210_000
        ]
        _ = try await postJSON(path: "/rest/v1/profiles", body: profileBody, auth: true)

        // 6. Store VEK in memory
        self.vek = newVEK
        self.isCloudAuthenticated = true
        self.cloudEmail = (authData["user"] as? [String: Any])?["email"] as? String
        self.state = .idle
    }

    func signInWithEmail(email: String, password: String, masterPassword: String) async throws {
        // 1. Authenticate with Supabase
        let authBody: [String: Any] = ["email": email, "password": password]
        let authData = try await postJSON(
            path: "/auth/v1/token?grant_type=password",
            body: authBody,
            auth: false
        )

        guard let token = authData["access_token"] as? String else {
            throw SyncError.serverError("Connexion échouée")
        }

        accessToken = token
        refreshToken = authData["refresh_token"] as? String
        cloudEmail = (authData["user"] as? [String: Any])?["email"] as? String
        saveSession()

        // 2. Unlock cloud vault with master password
        try await unlockCloud(masterPassword: masterPassword)
    }

    func unlockCloud(masterPassword: String) async throws {
        guard let token = accessToken else { throw SyncError.notAuthenticated }

        // Fetch profile
        let profileData = try await getJSON(path: "/rest/v1/profiles?select=*&limit=1")
        guard let profiles = profileData as? [[String: Any]],
              let profile = profiles.first,
              let wrappedVEKB64 = profile["wrapped_vek"] as? String,
              let vekSaltB64 = profile["vek_salt"] as? String,
              let wrappedVEK = Data(base64Encoded: wrappedVEKB64),
              let vekSalt = Data(base64Encoded: vekSaltB64) else {
            throw SyncError.serverError("Profil cloud introuvable")
        }

        let vekRounds = profile["vek_rounds"] as? Int ?? 210_000

        // Derive KEK and unwrap VEK
        let kek = CloudKeyManager.deriveKEK(masterPassword: masterPassword, salt: vekSalt, rounds: vekRounds)

        do {
            self.vek = try CloudKeyManager.unwrapVEK(wrappedVEK, with: kek)
            self.isCloudAuthenticated = true
            self.state = .idle
        } catch {
            throw SyncError.encryptionError("Mot de passe maître incorrect pour le cloud")
        }
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        vek = nil
        isCloudAuthenticated = false
        cloudEmail = nil
        state = .disabled
        clearSession()
    }

    // MARK: - Sync Operations

    func sync(localEntries: [VaultEntry]) async throws -> [VaultEntry] {
        guard let vek else { throw SyncError.notUnlocked }
        guard accessToken != nil else { throw SyncError.notAuthenticated }

        state = .syncing

        do {
            // 1. Fetch all remote items
            let remoteData = try await getJSON(path: "/rest/v1/vault_items?select=*&order=updated_at.desc")
            guard let remoteItems = remoteData as? [[String: Any]] else {
                state = .idle
                return localEntries
            }

            // 2. Decrypt remote items
            var remoteEntries: [(id: String, entry: VaultEntry, updatedAt: Date, deleted: Bool)] = []
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            for item in remoteItems {
                guard let remoteId = item["id"] as? String,
                      let blobB64 = item["encrypted_blob"] as? String,
                      let updatedAtStr = item["updated_at"] as? String,
                      let blob = Data(base64Encoded: blobB64) else { continue }

                let isDeleted = item["deleted_at"] != nil && !(item["deleted_at"] is NSNull)
                let updatedAt = dateFormatter.date(from: updatedAtStr) ?? Date.distantPast

                if !isDeleted {
                    if let entry = try? CloudKeyManager.decryptEntry(blob, with: vek) {
                        remoteEntries.append((id: remoteId, entry: entry, updatedAt: updatedAt, deleted: false))
                    }
                } else {
                    // Create placeholder for deleted entries
                    remoteEntries.append((id: remoteId, entry: VaultEntry(title: "", username: "", password: "", website: "", notes: ""), updatedAt: updatedAt, deleted: true))
                }
            }

            // 3. Merge: last-write-wins
            var merged = localEntries
            let localIDs = Set(localEntries.map { $0.id.uuidString })

            for remote in remoteEntries {
                if remote.deleted {
                    // Remove locally if remote was deleted
                    merged.removeAll { $0.id.uuidString == remote.id }
                    continue
                }

                if let localIdx = merged.firstIndex(where: { $0.id.uuidString == remote.id }) {
                    // Exists locally — last-write-wins
                    if remote.updatedAt > merged[localIdx].lastModifiedAt {
                        merged[localIdx] = remote.entry
                    }
                } else {
                    // New from remote
                    merged.insert(remote.entry, at: 0)
                }
            }

            // 4. Push local entries that don't exist remotely
            let remoteIDs = Set(remoteEntries.map { $0.id })
            for entry in merged {
                if !remoteIDs.contains(entry.id.uuidString) {
                    try await pushEntry(entry)
                }
            }

            // 5. Update local entries that are newer than remote
            for entry in merged {
                if let remote = remoteEntries.first(where: { $0.id == entry.id.uuidString }),
                   !remote.deleted,
                   entry.lastModifiedAt > remote.updatedAt {
                    try await pushEntry(entry)
                }
            }

            // 6. Update sync metadata
            try await updateSyncMetadata()

            state = .idle
            lastSyncDate = Date()
            return merged
        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }

    func pushEntry(_ entry: VaultEntry) async throws {
        guard let vek else { throw SyncError.notUnlocked }

        let encrypted = try CloudKeyManager.encryptEntry(entry, with: vek)
        let now = ISO8601DateFormatter().string(from: Date())

        let body: [String: Any] = [
            "id": entry.id.uuidString,
            "encrypted_blob": encrypted.base64EncodedString(),
            "updated_at": now
        ]

        // Upsert
        _ = try await postJSON(
            path: "/rest/v1/vault_items",
            body: body,
            auth: true,
            extraHeaders: ["Prefer": "resolution=merge-duplicates"]
        )
    }

    func deleteEntry(id: UUID) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let body: [String: Any] = ["deleted_at": now]
        _ = try await patchJSON(path: "/rest/v1/vault_items?id=eq.\(id.uuidString)", body: body)
    }

    // MARK: - REST Helpers

    private func postJSON(path: String, body: [String: Any], auth: Bool, extraHeaders: [String: String] = [:]) async throws -> [String: Any] {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        if auth, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }
        for (key, val) in extraHeaders {
            request.setValue(val, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SyncError.serverError(errorMsg)
        }

        if data.isEmpty { return [:] }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func getJSON(path: String) async throws -> Any {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            throw SyncError.serverError(String(data: data, encoding: .utf8) ?? "Error")
        }

        return try JSONSerialization.jsonObject(with: data)
    }

    private func patchJSON(path: String, body: [String: Any]) async throws -> [String: Any] {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            throw SyncError.serverError(String(data: data, encoding: .utf8) ?? "Error")
        }

        if data.isEmpty { return [:] }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Sync Metadata

    private func updateSyncMetadata() async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let body: [String: Any] = [
            "device_id": deviceID,
            "device_name": Self.deviceName(),
            "last_sync_at": now
        ]
        _ = try await postJSON(
            path: "/rest/v1/sync_metadata",
            body: body,
            auth: true,
            extraHeaders: ["Prefer": "resolution=merge-duplicates"]
        )
    }

    // MARK: - Session Persistence (tokens only, never VEK)

    private func saveSession() {
        if let token = accessToken {
            try? KeychainService.save(data: Data(token.utf8), key: "fyxxvault.cloud.access.token")
        }
        if let refresh = refreshToken {
            try? KeychainService.save(data: Data(refresh.utf8), key: "fyxxvault.cloud.refresh.token")
        }
        if let email = cloudEmail {
            UserDefaults.standard.set(email, forKey: "fyxxvault.cloud.email")
        }
    }

    private func loadSession() {
        if let tokenData = KeychainService.loadOptionalData(for: "fyxxvault.cloud.access.token"),
           let token = String(data: tokenData, encoding: .utf8) {
            accessToken = token
            cloudEmail = UserDefaults.standard.string(forKey: "fyxxvault.cloud.email")
            isCloudAuthenticated = false // Need to unlock with master password
            state = .disabled // Will be enabled after unlock
        }
    }

    private func clearSession() {
        KeychainService.delete(key: "fyxxvault.cloud.access.token")
        KeychainService.delete(key: "fyxxvault.cloud.refresh.token")
        UserDefaults.standard.removeObject(forKey: "fyxxvault.cloud.email")
    }

    // MARK: - Device ID

    private static func getOrCreateDeviceID() -> String {
        let key = "fyxxvault.sync.device.id"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    private static func deviceName() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? "Mac"
        #endif
    }
}
