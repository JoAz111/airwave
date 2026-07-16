import Foundation

enum StationRanker {
    private struct GroupKey: Hashable {
        let name: String
        let countryCode: String
        let homepageHost: String
    }

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

    static func group(_ stations: [Station]) -> [Station] {
        var grouped: [GroupKey: Station] = [:]
        var ungrouped: [Station] = []

        for station in stations {
            guard
                let countryCode = station.countryCode?.lowercased(),
                let homepageURL = station.homepageURL,
                let homepageHost = URLComponents(
                    url: homepageURL,
                    resolvingAgainstBaseURL: false
                )?.host?.lowercased()
            else {
                ungrouped.append(station)
                continue
            }

            let key = GroupKey(
                name: station.name.folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: .current
                ),
                countryCode: countryCode,
                homepageHost: homepageHost
            )

            if var existing = grouped[key] {
                existing.sources = sortedSources(
                    Array(Set(existing.sources + station.sources))
                )
                existing.votes = max(existing.votes, station.votes)
                grouped[key] = existing
            } else {
                var copy = station
                copy.sources = sortedSources(copy.sources)
                grouped[key] = copy
            }
        }

        return rank(Array(grouped.values) + ungrouped)
    }

    static func plausibleBitrate(_ value: Int?) -> Int? {
        guard let value, (16 ... 512).contains(value) else {
            return nil
        }
        return value
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
