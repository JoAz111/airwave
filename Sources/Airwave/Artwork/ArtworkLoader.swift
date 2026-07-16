import AppKit
import Foundation

@MainActor final class ArtworkLoader {
    private let cache = NSCache<NSURL, NSImage>()
    private let session: URLSession

    init() {
        cache.totalCostLimit = 24 * 1_024 * 1_024
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 8 * 1_024 * 1_024, diskCapacity: 96 * 1_024 * 1_024)
        session = URLSession(configuration: configuration)
    }

    func image(for url: URL?) async -> NSImage? {
        guard let url, url.scheme == "https" else { return nil }
        if let image = cache.object(forKey: url as NSURL) { return image }
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse,
              (200 ... 299).contains(http.statusCode),
              let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: url as NSURL, cost: data.count)
        return image
    }
}
