import Foundation

protocol StationSearching: Sendable {
    func explore(countryCode: String?) async throws -> [Station]
    func search(_ query: String) async throws -> [Station]
    func stations(in countryCode: String, matching query: String) async throws -> [Station]
}

actor StationSearchService: StationSearching {
    private let directory: any RadioBrowserServing

    init(directory: any RadioBrowserServing) { self.directory = directory }

    func explore(countryCode: String?) async throws -> [Station] {
        StationRanker.group(try await request(
            nil,
            "",
            countryCode: countryCode,
            limit: 100,
            order: "clickcount"
        ))
    }

    func search(_ query: String) async throws -> [Station] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return try await explore(countryCode: nil) }
        return try await fieldSearch(value, countryCode: nil)
    }

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
