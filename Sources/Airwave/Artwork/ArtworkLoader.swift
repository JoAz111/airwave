import AppKit
import Foundation

@MainActor final class ArtworkLoader {
    private let cache = NSCache<NSURL, NSImage>()
    private let stationCache = NSCache<NSString, NSImage>()
    private let session: URLSession

    init() {
        cache.totalCostLimit = 24 * 1_024 * 1_024
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 8 * 1_024 * 1_024, diskCapacity: 96 * 1_024 * 1_024)
        session = URLSession(configuration: configuration)
    }

    func image(for station: Station) async -> NSImage? {
        let cacheKey = station.id.uuidString as NSString
        if let image = stationCache.object(forKey: cacheKey) { return image }

        for url in directIconURLs(for: station) {
            if let image = await image(for: url) {
                stationCache.setObject(image, forKey: cacheKey)
                return image
            }
        }

        guard let homepageURL = station.homepageURL else { return nil }
        let discoveredURLs = await discoverIconURLs(at: homepageURL)
        let fallbackURLs = ["/apple-touch-icon.png", "/favicon.ico"].compactMap {
            URL(string: $0, relativeTo: homepageURL)?.absoluteURL
        }

        for url in discoveredURLs + fallbackURLs {
            for candidate in secureCandidates(for: url) {
                if let image = await image(for: candidate) {
                    stationCache.setObject(image, forKey: cacheKey)
                    return image
                }
            }
        }

        return nil
    }

    func image(for url: URL?) async -> NSImage? {
        guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            return nil
        }
        if let image = cache.object(forKey: url as NSURL) { return image }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200 ... 299).contains(http.statusCode),
              let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: url as NSURL, cost: data.count)
        return image
    }

    private func directIconURLs(for station: Station) -> [URL] {
        guard let faviconURL = station.faviconURL else { return [] }
        let resolvedURL: URL
        if faviconURL.scheme == nil, let homepageURL = station.homepageURL {
            resolvedURL = URL(
                string: faviconURL.relativeString,
                relativeTo: homepageURL
            )?.absoluteURL ?? faviconURL
        } else {
            resolvedURL = faviconURL
        }
        return secureCandidates(for: resolvedURL)
    }

    private func secureCandidates(for url: URL) -> [URL] {
        guard url.scheme?.lowercased() == "http",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return [url]
        }
        components.scheme = "https"
        guard let secureURL = components.url else { return [url] }
        return [secureURL, url]
    }

    private func discoverIconURLs(at homepageURL: URL) async -> [URL] {
        for url in secureCandidates(for: homepageURL) {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            request.setValue("text/html", forHTTPHeaderField: "Accept")
            guard let (data, response) = try? await session.data(for: request),
                  let http = response as? HTTPURLResponse,
                  (200 ... 299).contains(http.statusCode) else {
                continue
            }
            let html = String(decoding: data.prefix(524_288), as: UTF8.self)
            return Self.iconURLs(
                in: html,
                baseURL: response.url ?? url
            )
        }
        return []
    }

    nonisolated static func iconURLs(in html: String, baseURL: URL) -> [URL] {
        let tagPattern = #"<link\b[^>]*>"#
        guard let expression = try? NSRegularExpression(
            pattern: tagPattern,
            options: [.caseInsensitive]
        ) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        return expression.matches(in: html, range: range).compactMap { match in
            guard let tagRange = Range(match.range, in: html) else { return nil }
            let tag = String(html[tagRange])
            guard let relationship = attribute("rel", in: tag)?.lowercased(),
                  relationship.contains("icon"),
                  let rawURL = attribute("href", in: tag) else {
                return nil
            }
            return URL(
                string: rawURL.replacingOccurrences(of: "&amp;", with: "&"),
                relativeTo: baseURL
            )?.absoluteURL
        }
    }

    nonisolated private static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: name)
            + #"\s*=\s*[\"']([^\"']+)[\"']"#
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else { return nil }
        let range = NSRange(tag.startIndex..., in: tag)
        guard let match = expression.firstMatch(in: tag, range: range),
              let valueRange = Range(match.range(at: 1), in: tag) else {
            return nil
        }
        return String(tag[valueRange])
    }
}
