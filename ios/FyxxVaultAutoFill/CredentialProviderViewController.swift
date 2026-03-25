import AuthenticationServices
import UIKit

/// AutoFill Credential Provider for FyxxVault.
/// This extension allows iOS to suggest vault credentials in Safari and other apps.
///
/// Data flow:
/// 1. iOS calls this extension when the user taps an AutoFill suggestion
/// 2. We read the encrypted vault from the shared App Group container
/// 3. We decrypt using the symmetric key from the shared Keychain access group
/// 4. We match credentials by domain and return the selected one to iOS
final class CredentialProviderViewController: ASCredentialProviderViewController {

    // MARK: - Credential Provider Lifecycle

    /// Called when the user selects a credential from the QuickType bar (no UI needed).
    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        // Try to provide the credential directly (if vault is already unlocked / key accessible)
        guard let credential = findCredential(for: credentialIdentity) else {
            extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
            return
        }
        extensionContext.completeRequest(withSelectedCredential: credential)
    }

    /// Called when the system shows the credential list. We populate it with matching entries.
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        // Load all vault entries and filter by matching service identifiers
        let entries = loadVaultEntries()
        let matching = filterEntries(entries, for: serviceIdentifiers)

        if matching.isEmpty {
            // Show all entries if no match found
            presentCredentialList(entries: entries)
        } else {
            presentCredentialList(entries: matching)
        }
    }

    /// Called when user picks an entry from our credential list UI.
    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        // Provide the credential for the selected identity
        if let credential = findCredential(for: credentialIdentity) {
            extensionContext.completeRequest(withSelectedCredential: credential)
        } else {
            extensionContext.cancelRequest(withError: ASExtensionError(.credentialIdentityNotFound))
        }
    }

    // MARK: - Vault Access (Shared Container)

    private func loadVaultEntries() -> [AutoFillEntry] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedConfig.appGroupIdentifier
        ) else { return [] }

        let vaultURL = containerURL.appendingPathComponent("FyxxVaultData/vault.enc")
        guard let rawData = try? Data(contentsOf: vaultURL) else { return [] }

        // Load symmetric key from shared Keychain
        guard let keyData = SharedKeychainService.loadData(for: SharedConfig.vaultSymmetricKeyAccount) else {
            return []
        }

        do {
            // Unwrap HMAC header if present
            let ciphertext: Data
            if rawData.prefix(4) == Data([0x46, 0x59, 0x58, 0x56]) { // "FYXV" magic
                ciphertext = try SharedCrypto.unwrapVaultData(rawData, keyData: keyData)
            } else {
                ciphertext = rawData
            }

            let decrypted = try SharedCrypto.decrypt(data: ciphertext, with: keyData)
            let decoder = JSONDecoder()

            if let db = try? decoder.decode(AutoFillVaultDatabase.self, from: decrypted) {
                return db.entries
            } else if let entries = try? decoder.decode([AutoFillEntry].self, from: decrypted) {
                return entries
            }
        } catch {
            // Decryption failed — vault is locked or corrupted
        }

        return []
    }

    private func findCredential(for identity: ASPasswordCredentialIdentity) -> ASPasswordCredential? {
        let entries = loadVaultEntries()

        // Try to match by record identifier (entry UUID)
        if let recordID = identity.recordIdentifier,
           let entry = entries.first(where: { $0.id.uuidString == recordID }) {
            return ASPasswordCredential(user: entry.username, password: entry.password)
        }

        // Fall back to matching by service identifier (domain)
        let matching = filterEntries(entries, for: [identity.serviceIdentifier])
        if let entry = matching.first {
            return ASPasswordCredential(user: entry.username, password: entry.password)
        }

        return nil
    }

    private func filterEntries(_ entries: [AutoFillEntry], for serviceIdentifiers: [ASCredentialServiceIdentifier]) -> [AutoFillEntry] {
        guard !serviceIdentifiers.isEmpty else { return entries }

        return entries.filter { entry in
            let entryDomain = extractDomain(from: entry.website).lowercased()
            guard !entryDomain.isEmpty else { return false }

            return serviceIdentifiers.contains { identifier in
                let serviceDomain = extractDomain(from: identifier.identifier).lowercased()
                return entryDomain.contains(serviceDomain) || serviceDomain.contains(entryDomain)
            }
        }
    }

    private func extractDomain(from urlString: String) -> String {
        let cleaned = urlString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")

        return cleaned.components(separatedBy: "/").first ?? cleaned
    }

    // MARK: - Credential List UI

    private func presentCredentialList(entries: [AutoFillEntry]) {
        let tableVC = AutoFillTableViewController(entries: entries) { [weak self] entry in
            let credential = ASPasswordCredential(user: entry.username, password: entry.password)
            self?.extensionContext.completeRequest(withSelectedCredential: credential)
        }
        tableVC.cancelHandler = { [weak self] in
            self?.extensionContext.cancelRequest(withError: ASExtensionError(.userCanceled))
        }

        let nav = UINavigationController(rootViewController: tableVC)
        nav.modalPresentationStyle = .fullScreen

        // Remove existing child VCs before presenting
        children.forEach { $0.removeFromParent() }
        addChild(nav)
        nav.view.frame = view.bounds
        nav.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(nav.view)
        nav.didMove(toParent: self)
    }
}

// MARK: - Lightweight Models (Extension-only, no SwiftUI dependency)

struct AutoFillEntry: Codable, Identifiable {
    var id: UUID
    var title: String
    var username: String
    var password: String
    var website: String

    private enum CodingKeys: String, CodingKey {
        case id, title, username, password, website
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        username = try container.decode(String.self, forKey: .username)
        password = try container.decode(String.self, forKey: .password)
        website = try container.decode(String.self, forKey: .website)
    }
}

struct AutoFillVaultDatabase: Codable {
    var entries: [AutoFillEntry]

    private enum CodingKeys: String, CodingKey {
        case entries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entries = (try? container.decode([AutoFillEntry].self, forKey: .entries)) ?? []
    }
}

// MARK: - Credential List Table View Controller

final class AutoFillTableViewController: UITableViewController {
    private let entries: [AutoFillEntry]
    private let selectionHandler: (AutoFillEntry) -> Void
    var cancelHandler: (() -> Void)?

    init(entries: [AutoFillEntry], selectionHandler: @escaping (AutoFillEntry) -> Void) {
        self.entries = entries
        self.selectionHandler = selectionHandler
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "FyxxVault"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        // Dark theme to match main app
        view.backgroundColor = UIColor(red: 12/255, green: 12/255, blue: 20/255, alpha: 1)
        tableView.backgroundColor = view.backgroundColor
    }

    @objc private func cancelTapped() {
        cancelHandler?()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let entry = entries[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = entry.title
        config.secondaryText = entry.username
        config.textProperties.color = .white
        config.secondaryTextProperties.color = .lightGray
        cell.contentConfiguration = config
        cell.backgroundColor = UIColor(white: 1, alpha: 0.05)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectionHandler(entries[indexPath.row])
    }
}
