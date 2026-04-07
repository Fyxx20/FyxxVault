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
    @Published var cloudIsProUser: Bool = false

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
            "wrapped_vek": encodeSupabaseBytes(wrappedVEK),
            "vek_salt": encodeSupabaseBytes(salt),
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
        guard accessToken != nil else { throw SyncError.notAuthenticated }
        // Ensure token is fresh before fetching profile
        if let fresh = await getValidAccessToken() { accessToken = fresh }

        // Fetch profile
        let profileData = try await getJSON(path: "/rest/v1/profiles?select=*&limit=1")
        guard let profiles = profileData as? [[String: Any]],
              let profile = profiles.first,
              let wrappedVEKRaw = profile["wrapped_vek"] as? String,
              let vekSaltRaw = profile["vek_salt"] as? String,
              let wrappedVEK = decodeSupabaseBytes(wrappedVEKRaw),
              let vekSalt = decodeSupabaseBytes(vekSaltRaw) else {
            throw SyncError.serverError("Profil cloud introuvable")
        }

        let vekRounds = profile["vek_rounds"] as? Int ?? 210_000

        // Derive KEK and unwrap VEK
        let kek = CloudKeyManager.deriveKEK(masterPassword: masterPassword, salt: vekSalt, rounds: vekRounds)

        do {
            self.vek = try CloudKeyManager.unwrapVEK(wrappedVEK, with: kek)
            self.isCloudAuthenticated = true
            // Read is_pro — handle Bool, Int (1/0), String ("true"/"false")
            let rawPro = profile["is_pro"]
            if let boolVal = rawPro as? Bool {
                self.cloudIsProUser = boolVal
            } else if let intVal = rawPro as? Int {
                self.cloudIsProUser = intVal == 1
            } else if let strVal = rawPro as? String {
                self.cloudIsProUser = strVal == "true" || strVal == "1"
            } else {
                self.cloudIsProUser = false
            }
            print("[SyncService] unlockCloud: is_pro raw=\(String(describing: rawPro)) → cloudIsProUser=\(self.cloudIsProUser)")
            self.state = .idle
        } catch {
            throw SyncError.encryptionError("Mot de passe maître incorrect pour le cloud")
        }
    }

    /// Configure SyncService with a token already obtained by SupabaseAuthService,
    /// then unlock the cloud vault with the master password.
    /// This avoids a redundant /auth/v1/token call when SupabaseAuthService already signed in.
    func configureWithToken(_ token: String, refresh: String? = nil, email: String?, masterPassword: String) async throws {
        self.accessToken = token
        if let refresh { self.refreshToken = refresh }
        self.cloudEmail = email
        saveSession()
        print("[SyncService] configureWithToken: token=\(token.prefix(20))… refresh=\(self.refreshToken != nil ? "yes" : "no") email=\(email ?? "nil")")

        // Unlock cloud vault (fetches profile, derives KEK, unwraps VEK)
        try await unlockCloud(masterPassword: masterPassword)
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

    // MARK: - Cloud Pro Status

    /// Refresh Pro status from Supabase profile (Stripe webhook sets is_pro)
    func refreshCloudProStatus() async {
        guard let token = await getValidAccessToken() else {
            print("[SyncService] refreshCloudProStatus: no valid token")
            return
        }
        do {
            let url = URL(string: baseURL + "/rest/v1/profiles?select=is_pro&limit=1")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let rawBody = String(data: data, encoding: .utf8) ?? ""
            print("[SyncService] refreshCloudProStatus: HTTP \(httpCode) body=\(rawBody)")
            guard httpCode < 400 else { return }
            if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let profile = json.first {
                let rawPro = profile["is_pro"]
                var isPro = false
                if let b = rawPro as? Bool { isPro = b }
                else if let i = rawPro as? Int { isPro = i == 1 }
                else if let s = rawPro as? String { isPro = s == "true" || s == "1" }
                print("[SyncService] refreshCloudProStatus: raw=\(String(describing: rawPro)) → isPro=\(isPro)")
                cloudIsProUser = isPro
            }
        } catch {
            print("[SyncService] refreshCloudProStatus error: \(error)")
        }
    }

    // MARK: - Sync Operations

    func sync(localEntries: [VaultEntry]) async throws -> [VaultEntry] {
        guard let vek else {
            print("[SyncService] sync: VEK is nil — vault not unlocked")
            throw SyncError.notUnlocked
        }
        // Ensure we have a valid (non-expired) token
        guard let validToken = await getValidAccessToken() else {
            print("[SyncService] sync: no valid token available")
            throw SyncError.notAuthenticated
        }
        // Update accessToken for REST calls
        accessToken = validToken

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
            var decryptionFailures = 0
            var activeRemoteCount = 0

            for item in remoteItems {
                guard let remoteId = item["id"] as? String,
                      let updatedAtStr = item["updated_at"] as? String else { continue }

                let isDeleted = item["deleted_at"] != nil && !(item["deleted_at"] is NSNull)
                let updatedAt = dateFormatter.date(from: updatedAtStr) ?? Date.distantPast

                if isDeleted {
                    // Deleted entry — no need for blob, just track for removal
                    remoteEntries.append((id: remoteId, entry: VaultEntry(title: "", username: "", password: "", website: "", notes: ""), updatedAt: updatedAt, deleted: true))
                } else {
                    activeRemoteCount += 1
                    // Active entry — needs blob + decryption
                    guard let blobRaw = item["encrypted_blob"] as? String else {
                        print("[SyncService] ⚠️ Missing encrypted_blob for entry \(remoteId)")
                        decryptionFailures += 1
                        continue
                    }
                    guard let blob = decodeSupabaseBytes(blobRaw) else {
                        print("[SyncService] ⚠️ Failed to decode BYTEA for entry \(remoteId) — raw prefix: \(blobRaw.prefix(30))")
                        decryptionFailures += 1
                        continue
                    }
                    do {
                        let entry = try CloudKeyManager.decryptEntry(blob, with: vek)
                        remoteEntries.append((id: remoteId, entry: entry, updatedAt: updatedAt, deleted: false))
                    } catch {
                        print("[SyncService] ⚠️ Decryption failed for entry \(remoteId): \(error)")
                        decryptionFailures += 1
                    }
                }
            }
            let activeDecrypted = remoteEntries.filter { !$0.deleted }.count
            print("[SyncService] sync: \(remoteItems.count) remote items → \(activeDecrypted) active decrypted, \(remoteEntries.filter { $0.deleted }.count) deleted, \(decryptionFailures) decrypt failures")

            // SAFETY: If remote has active entries but ALL failed decryption, don't wipe local vault
            if activeRemoteCount > 0 && activeDecrypted == 0 {
                print("[SyncService] ⚠️ ALL \(activeRemoteCount) active entries failed decryption — keeping local vault intact (\(localEntries.count) entries)")
                state = .error("Échec déchiffrement cloud")
                return localEntries
            }

            // 3. Merge: last-write-wins (case-insensitive UUID comparison)
            var merged = localEntries

            for remote in remoteEntries {
                let remoteIdUpper = remote.id.uppercased()

                if remote.deleted {
                    // Remove locally if remote was deleted
                    merged.removeAll { $0.id.uuidString.uppercased() == remoteIdUpper }
                    continue
                }

                if let localIdx = merged.firstIndex(where: { $0.id.uuidString.uppercased() == remoteIdUpper }) {
                    // Exists locally — last-write-wins
                    if remote.updatedAt > merged[localIdx].lastModifiedAt {
                        merged[localIdx] = remote.entry
                    }
                } else {
                    // New from remote
                    merged.insert(remote.entry, at: 0)
                }
            }

            print("[SyncService] sync: after merge → \(merged.count) entries (was \(localEntries.count) local)")

            // 4. Push local entries that don't exist remotely
            let remoteIDs = Set(remoteEntries.map { $0.id.uppercased() })
            for entry in merged {
                if !remoteIDs.contains(entry.id.uuidString.uppercased()) {
                    try await pushEntry(entry)
                }
            }

            // 5. Update local entries that are newer than remote
            for entry in merged {
                if let remote = remoteEntries.first(where: { $0.id.uppercased() == entry.id.uuidString.uppercased() }),
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
        // Ensure fresh token
        if let fresh = await getValidAccessToken() { accessToken = fresh }

        let encrypted = try CloudKeyManager.encryptEntry(entry, with: vek)
        let now = ISO8601DateFormatter().string(from: Date())

        let body: [String: Any] = [
            "id": entry.id.uuidString,
            "encrypted_blob": encodeSupabaseBytes(encrypted),
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

    // MARK: - Supabase BYTEA Helpers

    /// Decode a Postgres BYTEA value returned as "\\x<hex>" or plain base64.
    private func decodeSupabaseBytes(_ value: String) -> Data? {
        var hex = value
        if hex.hasPrefix("\\x") { hex = String(hex.dropFirst(2)) }
        else if hex.hasPrefix("0x") { hex = String(hex.dropFirst(2)) }
        else {
            // Try base64 fallback
            return Data(base64Encoded: value)
        }
        guard hex.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return Data(bytes)
    }

    /// Encode Data as a Postgres BYTEA hex string "\\x<hex>".
    private func encodeSupabaseBytes(_ data: Data) -> String {
        "\\x" + data.map { String(format: "%02x", $0) }.joined()
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

    // MARK: - Token Refresh

    /// Refreshes the Supabase access token using the stored refresh token.
    /// Updates both in-memory and keychain tokens.
    func refreshAccessToken() async -> Bool {
        guard let refreshData = KeychainService.loadOptionalData(for: "fyxxvault.cloud.refresh.token"),
              let refresh = String(data: refreshData, encoding: .utf8) else {
            print("[SyncService] No refresh token available")
            return false
        }
        do {
            let body: [String: Any] = ["refresh_token": refresh]
            let url = URL(string: baseURL + "/auth/v1/token?grant_type=refresh_token")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
                print("[SyncService] Token refresh failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return false
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newAccess = json["access_token"] as? String else {
                return false
            }
            accessToken = newAccess
            if let newRefresh = json["refresh_token"] as? String {
                refreshToken = newRefresh
            }
            saveSession()
            print("[SyncService] Token refreshed successfully")
            return true
        } catch {
            print("[SyncService] Token refresh error: \(error)")
            return false
        }
    }

    /// Check if current JWT is expired by decoding the exp claim
    var isTokenExpired: Bool {
        guard let token = accessToken else { return true }
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return true }
        var base64 = String(parts[1])
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else { return true }
        // Consider expired if less than 60 seconds remaining
        return Date().timeIntervalSince1970 >= (exp - 60)
    }

    /// Returns a valid access token, refreshing if needed. Updates keychain.
    func getValidAccessToken() async -> String? {
        if isTokenExpired {
            let success = await refreshAccessToken()
            if !success { return nil }
        }
        return accessToken
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
