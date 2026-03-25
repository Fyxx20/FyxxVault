import SwiftUI

@MainActor
final class FaviconCache {
    static let shared = FaviconCache()
    private var cache: [String: UIImage] = [:]

    func image(for domain: String) -> UIImage? {
        cache[domain]
    }

    func loadFavicon(for urlString: String) async -> UIImage? {
        let domain = extractDomain(from: urlString)
        guard !domain.isEmpty else { return nil }

        if let cached = cache[domain] { return cached }

        // Try Google's favicon service (fast, reliable, no API key needed)
        let faviconURL = "https://www.google.com/s2/favicons?domain=\(domain)&sz=64"

        guard let url = URL(string: faviconURL) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data),
                  image.size.width > 1 else { return nil }
            cache[domain] = image
            return image
        } catch {
            return nil
        }
    }

    private func extractDomain(from urlString: String) -> String {
        var cleaned = urlString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        if let slashIdx = cleaned.firstIndex(of: "/") {
            cleaned = String(cleaned[..<slashIdx])
        }
        return cleaned.lowercased()
    }
}

struct FaviconView: View {
    let urlString: String
    let size: CGFloat
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            } else {
                EmptyView()
            }
        }
        .task {
            image = await FaviconCache.shared.loadFavicon(for: urlString)
        }
    }
}
