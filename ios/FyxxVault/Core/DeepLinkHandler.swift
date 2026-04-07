import Foundation
import SwiftUI

enum DeepLink {
    case search(query: String)
    case addEntry
    case securityDashboard
    case settings

    init?(url: URL) {
        guard url.scheme == "fyxxvault" else { return nil }
        switch url.host {
        case "search":
            let query = url.queryParameters["q"] ?? ""
            self = .search(query: query)
        case "add":
            self = .addEntry
        case "security":
            self = .securityDashboard
        case "settings":
            self = .settings
        default:
            return nil
        }
    }
}

extension URL {
    var queryParameters: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return [:] }
        var params: [String: String] = [:]
        for item in queryItems {
            params[item.name] = item.value ?? ""
        }
        return params
    }
}
