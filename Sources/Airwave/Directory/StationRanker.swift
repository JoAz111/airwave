import Foundation

enum StationRanker {
    /// Sorts stations by usable stream quality, secure transport, directory votes, and name.
    static func rank(_ stations: [Station]) -> [Station] {
        stations
            .map { station in
                var copy = station
                copy.sources = sortedSources(station.sources)
                return copy
            }
            .sorted { lhs, rhs in
                let leftBitrate = plausibleBitrate(lhs.primarySource?.bitrate) ?? -1
                let rightBitrate = plausibleBitrate(rhs.primarySource?.bitrate) ?? -1
                if leftBitrate != rightBitrate {
                    return leftBitrate > rightBitrate
                }

                let leftHTTPS = lhs.primarySource?.url.scheme == "https"
                let rightHTTPS = rhs.primarySource?.url.scheme == "https"
                if leftHTTPS != rightHTTPS {
                    return leftHTTPS
                }

                if lhs.votes != rhs.votes {
                    return lhs.votes > rhs.votes
                }

                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    /// Merges directory duplicates before applying the shared playback-quality ranking.
    static func group(_ stations: [Station]) -> [Station] {
        let streamDeduplicated = merge(stations, keyedBy: streamKey)
        let nameDeduplicated = merge(streamDeduplicated, keyedBy: nameKey)
        return rank(nameDeduplicated)
    }

    /// Accepts realistic radio bitrates and rejects directory garbage values.
    static func plausibleBitrate(_ value: Int?) -> Int? {
        guard let value, (16 ... 512).contains(value) else {
            return nil
        }
        return value
    }

    /// Collapses duplicates using the supplied stable identity while retaining richer metadata.
    private static func merge(
        _ stations: [Station],
        keyedBy keyForStation: (Station) -> String?
    ) -> [Station] {
        var indexByKey: [String: Int] = [:]
        var result: [Station] = []

        for station in stations {
            guard let key = keyForStation(station) else {
                result.append(station)
                continue
            }

            if let index = indexByKey[key] {
                result[index] = merged(result[index], station)
            } else {
                indexByKey[key] = result.count
                result.append(station)
            }
        }

        return result
    }

    /// Keeps the richer station record and combines all known stream fallbacks.
    private static func merged(_ lhs: Station, _ rhs: Station) -> Station {
        var preferred = qualityScore(rhs) > qualityScore(lhs) ? rhs : lhs
        preferred.sources = sortedSources(Array(Set(lhs.sources + rhs.sources)))
        preferred.votes = max(lhs.votes, rhs.votes)
        return preferred
    }

    /// Scores the metadata and stream characteristics used when choosing a duplicate survivor.
    private static func qualityScore(_ station: Station) -> Int {
        let artwork = station.faviconURL == nil ? 0 : 1_000_000
        let homepage = station.homepageURL == nil ? 0 : 500_000
        let bitrate = (plausibleBitrate(station.primarySource?.bitrate) ?? 0) * 1_000
        return artwork + homepage + bitrate + min(max(station.votes, 0), 100_000)
    }

    /// Builds a privacy-neutral stream identity that ignores URL credentials and query noise.
    private static func streamKey(_ station: Station) -> String? {
        guard let source = station.sources.first,
              var components = URLComponents(
                  url: source.url,
                  resolvingAgainstBaseURL: false
              ),
              let host = components.host?.lowercased() else {
            return nil
        }
        components.scheme = nil
        components.host = nil
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        let port = components.port.map { ":\($0)" } ?? ""
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(host)\(port)/\(path.lowercased())"
    }

    /// Builds a country-scoped normalized name identity for mirror and frequency variants.
    private static func nameKey(_ station: Station) -> String? {
        let name = normalizedName(station.name)
        guard !name.isEmpty else { return nil }
        let country = station.countryCode?.lowercased()
            ?? station.country?.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            ).lowercased()
            ?? ""
        return "\(country)|\(name)"
    }

    private static func normalizedName(_ value: String) -> String {
        let folded = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        ).lowercased()
        let frequencyPattern = #"\b(?:7\d|8\d|9\d|10\d|110)[.,]\d+\s*(?:fm)?\b|\b(?:7\d|8\d|9\d|10\d|110)\s*fm\b"#
        let withoutFrequencies = folded.replacingOccurrences(
            of: frequencyPattern,
            with: " ",
            options: .regularExpression
        )
        let separated = String(withoutFrequencies.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? Character(String($0)) : " "
        })
        let ignored = Set(["fm", "live", "online", "stream"])
        return separated
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !ignored.contains($0) && !isFrequency($0) }
            .joined(separator: " ")
    }

    private static func isFrequency(_ token: String) -> Bool {
        guard token.hasSuffix("fm") else { return false }
        let number = String(token.dropLast(2))
        guard let value = Double(number) else { return false }
        return (70 ... 110.9).contains(value)
    }

    private static func sortedSources(_ sources: [StationSource]) -> [StationSource] {
        sources.sorted { lhs, rhs in
            let leftBitrate = plausibleBitrate(lhs.bitrate) ?? -1
            let rightBitrate = plausibleBitrate(rhs.bitrate) ?? -1
            if leftBitrate != rightBitrate {
                return leftBitrate > rightBitrate
            }

            let leftHTTPS = lhs.url.scheme == "https"
            let rightHTTPS = rhs.url.scheme == "https"
            if leftHTTPS != rightHTTPS {
                return leftHTTPS
            }

            return lhs.url.absoluteString < rhs.url.absoluteString
        }
    }
}
