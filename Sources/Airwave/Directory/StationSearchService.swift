import Foundation

/// Station discovery operations used by the observable app model.
protocol StationSearching: Sendable {
    /// Returns a locale-led collection for the Explore tab.
    func explore(countryCode: String?) async throws -> [Station]
    /// Searches the global directory across station name, language, and tags.
    func search(_ query: String) async throws -> [Station]
    /// Searches a single country while retaining the same multi-field matching.
    func stations(in countryCode: String, matching query: String) async throws -> [Station]
}

/// Combines the directory's narrow search endpoints into one deduplicated station result.
actor StationSearchService: StationSearching {
    private let directory: any RadioBrowserServing

    /// Creates a search service using the app's shared directory transport.
    init(directory: any RadioBrowserServing) { self.directory = directory }

    /// Ranks popular stations for the supplied locale, or globally without one.
    func explore(countryCode: String?) async throws -> [Station] {
        StationRanker.group(try await request(
            nil,
            "",
            countryCode: countryCode,
            limit: 100,
            order: "clickcount"
        ))
    }

    /// Searches globally and restores the explore collection for a blank query.
    func search(_ query: String) async throws -> [Station] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return try await explore(countryCode: nil) }
        return try await fieldSearch(value, countryCode: nil)
    }

    /// Searches within a country and restores its popular collection for a blank query.
    func stations(in countryCode: String, matching query: String) async throws -> [Station] {
        let code = countryCode.uppercased()
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return StationRanker.group(try await request(
                nil,
                "",
                countryCode: code,
                limit: 100,
                order: "clickcount"
            ))
        }
        return try await fieldSearch(value, countryCode: code)
    }

    /// Runs independent field searches concurrently and merges their overlapping results.
    private func fieldSearch(_ value: String, countryCode: String?) async throws -> [Station] {
        try Task.checkCancellation()
        async let names = request(.name, value, countryCode: countryCode)
        async let languages = request(.language, value, countryCode: countryCode)
        async let tags = request(.tag, value, countryCode: countryCode)
        let batches = try await [names, languages, tags]
        try Task.checkCancellation()
        var unique: [UUID: Station] = [:]
        for station in batches.flatMap({ $0 }) where unique[station.id] == nil {
            unique[station.id] = station
        }
        return StationRanker.group(Array(unique.values))
    }

    /// Issues one bounded Radio Browser request for a single searchable field.
    private func request(
        _ field: RadioBrowserQuery.Field?,
        _ value: String,
        countryCode: String?,
        limit: Int = 30,
        order: String = "votes"
    ) async throws -> [Station] {
        try await directory.stations(matching: RadioBrowserQuery(
            field: field,
            value: value,
            countryCode: countryCode,
            limit: limit,
            order: order,
            reverse: true
        ))
    }
}
