import AppKit
import Dispatch
import Foundation
import ImageIO

struct DecodedArtwork {
    let image: NSImage
    let cgImage: CGImage
    let pixelWidth: Int
    let pixelHeight: Int
    let bytesPerRow: Int

    var cost: Int { bytesPerRow * pixelHeight }
}

actor ArtworkRequestLimiter {
    private let limit: Int
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = max(1, limit)
        available = max(1, limit)
    }

    func acquire() async {
        if available > 0 {
            available -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            available = min(limit, available + 1)
        } else {
            waiters.removeFirst().resume()
        }
    }
}

@MainActor final class ArtworkLoader {
    private static let cacheCostLimit = 16 * 1_024 * 1_024
    private static let warningCacheCostLimit = 8 * 1_024 * 1_024

    private let cache = NSCache<NSString, NSImage>()
    private let stationIconCache = NSCache<NSString, NSURL>()
    private let requestLimiter = ArtworkRequestLimiter(limit: 8)
    private let session: URLSession
    private let memoryPressureSource: any DispatchSourceMemoryPressure
    private var shouldCacheImages = true

    init() {
        cache.totalCostLimit = Self.cacheCostLimit
        cache.countLimit = 80
        stationIconCache.countLimit = 256

        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 0,
            diskCapacity: 96 * 1_024 * 1_024
        )
        configuration.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration: configuration)

        let pressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: .all,
            queue: .main
        )
        memoryPressureSource = pressureSource
        pressureSource.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        pressureSource.activate()
    }

    nonisolated static func decode(_ data: Data, maxPixelSize: Int) -> DecodedArtwork? {
        guard maxPixelSize > 0,
              let source = CGImageSourceCreateWithData(
                  data as CFData,
                  [kCGImageSourceShouldCache: false] as CFDictionary
              ) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: thumbnail.width,
                  height: thumbnail.height,
                  bitsPerComponent: 8,
                  bytesPerRow: thumbnail.width * 4,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(
            thumbnail,
            in: CGRect(x: 0, y: 0, width: thumbnail.width, height: thumbnail.height)
        )
        guard let cgImage = context.makeImage() else { return nil }

        return DecodedArtwork(
            image: NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            ),
            cgImage: cgImage,
            pixelWidth: cgImage.width,
            pixelHeight: cgImage.height,
            bytesPerRow: cgImage.bytesPerRow
        )
    }

    func image(for station: Station, maxPixelSize: Int = 320) async -> NSImage? {
        let pixelSize = max(32, maxPixelSize)
        let stationKey = station.id.uuidString as NSString

        if let resolvedURL = stationIconCache.object(forKey: stationKey),
           let image = await stationImage(
               for: resolvedURL as URL,
               maxPixelSize: pixelSize
           ) {
            return image
        }

        for url in directIconURLs(for: station) {
            guard !Task.isCancelled else { return nil }
            if let image = await stationImage(for: url, maxPixelSize: pixelSize) {
                cacheStationIcon(url, forKey: stationKey)
                return image
            }
        }

        guard !Task.isCancelled else { return nil }
        guard let homepageURL = station.homepageURL else { return nil }
        let discoveredURLs = await discoverIconURLs(at: homepageURL)
        let fallbackURLs = ["/apple-touch-icon.png", "/favicon.ico"].compactMap {
            URL(string: $0, relativeTo: homepageURL)?.absoluteURL
        }

        for url in discoveredURLs + fallbackURLs {
            for candidate in secureCandidates(for: url) {
                guard !Task.isCancelled else { return nil }
                if let image = await stationImage(for: candidate, maxPixelSize: pixelSize) {
                    cacheStationIcon(candidate, forKey: stationKey)
                    return image
                }
            }
        }

        return nil
    }

    func image(for url: URL?, maxPixelSize: Int = 320) async -> NSImage? {
        await image(
            for: url,
            maxPixelSize: maxPixelSize,
            requiresStationValidation: false
        )
    }

    private func stationImage(for url: URL?, maxPixelSize: Int) async -> NSImage? {
        await image(
            for: url,
            maxPixelSize: maxPixelSize,
            requiresStationValidation: true
        )
    }

    private func image(
        for url: URL?,
        maxPixelSize: Int,
        requiresStationValidation: Bool
    ) async -> NSImage? {
        guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            return nil
        }
        let pixelSize = max(32, maxPixelSize)
        let validationKey = requiresStationValidation ? "station" : "general"
        let cacheKey = "\(url.absoluteString)#\(pixelSize)#\(validationKey)" as NSString
        if let image = cache.object(forKey: cacheKey) { return image }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await fetch(request)
            guard let http = response as? HTTPURLResponse,
                  (200 ... 299).contains(http.statusCode),
                  !requiresStationValidation || Self.isUsableStationArtwork(data),
                  let decoded = Self.decode(data, maxPixelSize: pixelSize) else {
                return nil
            }
            if shouldCacheImages {
                cache.setObject(decoded.image, forKey: cacheKey, cost: decoded.cost)
            }
            return decoded.image
        } catch {
            return nil
        }
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
            guard !Task.isCancelled else { return [] }
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            request.setValue("text/html", forHTTPHeaderField: "Accept")
            guard let result = try? await fetch(request),
                  let http = result.1 as? HTTPURLResponse,
                  (200 ... 299).contains(http.statusCode) else {
                continue
            }
            let data = result.0
            let html = String(decoding: data.prefix(524_288), as: UTF8.self)
            return Self.iconURLs(
                in: html,
                baseURL: result.1.url ?? url
            )
        }
        return []
    }

    private func fetch(_ request: URLRequest) async throws -> (Data, URLResponse) {
        await requestLimiter.acquire()
        let result: (Data, URLResponse)
        do {
            try Task.checkCancellation()
            result = try await session.data(for: request)
        } catch {
            await requestLimiter.release()
            throw error
        }
        await requestLimiter.release()
        try Task.checkCancellation()
        return result
    }

    private func cacheStationIcon(_ url: URL, forKey key: NSString) {
        guard shouldCacheImages else { return }
        stationIconCache.setObject(url as NSURL, forKey: key)
    }

    private func handleMemoryPressure() {
        let event = memoryPressureSource.data
        if event.contains(.critical) {
            shouldCacheImages = false
            cache.removeAllObjects()
            stationIconCache.removeAllObjects()
        } else if event.contains(.warning) {
            shouldCacheImages = false
            cache.totalCostLimit = Self.warningCacheCostLimit
            cache.countLimit = 32
        } else if event.contains(.normal) {
            shouldCacheImages = true
            cache.totalCostLimit = Self.cacheCostLimit
            cache.countLimit = 80
        }
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

    nonisolated static func isUsableStationArtwork(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ),
              let properties = CGImageSourceCopyPropertiesAtIndex(
                  source,
                  0,
                  [kCGImageSourceShouldCache: false] as CFDictionary
              ) as NSDictionary?,
              let width = imageDimension(
                  in: properties,
                  primaryKey: kCGImagePropertyPixelWidth,
                  fallbackKey: kCGImagePropertyWidth
              ),
              let height = imageDimension(
                  in: properties,
                  primaryKey: kCGImagePropertyPixelHeight,
                  fallbackKey: kCGImagePropertyHeight
              ),
              hasUsableDimensions(width: width, height: height),
              let sample = decode(data, maxPixelSize: 32) else {
            return false
        }
        return hasSubstantialContent(in: sample.cgImage)
    }

    nonisolated private static func imageDimension(
        in properties: NSDictionary,
        primaryKey: CFString,
        fallbackKey: CFString
    ) -> Int? {
        (properties[primaryKey] as? NSNumber)?.intValue
            ?? (properties[fallbackKey] as? NSNumber)?.intValue
    }

    nonisolated private static func hasUsableDimensions(width: Int, height: Int) -> Bool {
        guard min(width, height) >= 96 else { return false }
        return (0.60 ... 1.67).contains(Double(width) / Double(height))
    }

    nonisolated private static func hasSubstantialContent(in image: CGImage) -> Bool {
        let bitmap = NSBitmapImageRep(cgImage: image)
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        let sampleSize = min(32, width, height)
        guard sampleSize > 0 else { return false }
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
