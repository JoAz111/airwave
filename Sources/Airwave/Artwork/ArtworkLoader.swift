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
            if let image = await image(for: url), Self.isUsableStationArtwork(image) {
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
                if let image = await image(for: candidate), Self.isUsableStationArtwork(image) {
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

    nonisolated static func isUsableStationArtwork(_ image: NSImage) -> Bool {
        guard let data = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data) else {
            return false
        }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        guard min(width, height) >= 96 else { return false }

        let aspectRatio = Double(width) / Double(height)
        guard (0.60 ... 1.67).contains(aspectRatio) else { return false }

        let sampleSize = 32
        let cornerPoints = [
            (0, 0),
            (width - 1, 0),
            (0, height - 1),
            (width - 1, height - 1)
        ]
        let corners = cornerPoints.compactMap { bitmap.colorAt(x: $0.0, y: $0.1) }
        guard !corners.isEmpty else { return false }

        let background = corners.reduce((red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)) {
            (
                $0.red + $1.redComponent,
                $0.green + $1.greenComponent,
                $0.blue + $1.blueComponent,
                $0.alpha + $1.alphaComponent
            )
        }
        let divisor = CGFloat(corners.count)
        let reference = (
            red: background.red / divisor,
            green: background.green / divisor,
            blue: background.blue / divisor,
            alpha: background.alpha / divisor
        )

        var minX = sampleSize
        var minY = sampleSize
        var maxX = -1
        var maxY = -1

        for y in 0 ..< sampleSize {
            for x in 0 ..< sampleSize {
                let pixelX = min(width - 1, x * width / sampleSize)
                let pixelY = min(height - 1, y * height / sampleSize)
                guard let color = bitmap.colorAt(x: pixelX, y: pixelY) else { continue }
                let distance = abs(color.redComponent - reference.red)
                    + abs(color.greenComponent - reference.green)
                    + abs(color.blueComponent - reference.blue)
                    + abs(color.alphaComponent - reference.alpha)
                guard color.alphaComponent > 0.05, distance > 0.18 else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return false }
        let contentWidth = Double(maxX - minX + 1) / Double(sampleSize)
        let contentHeight = Double(maxY - minY + 1) / Double(sampleSize)
        return contentWidth >= 0.18 && contentHeight >= 0.18
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
