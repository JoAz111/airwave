import Foundation

protocol StationSearching: Sendable {
    func explore() async throws -> [Station]
    func search(_ query: String) async throws -> [Station]
}

actor StationSearchService: StationSearching {
    private let directory: any RadioBrowserServing

    init(directory: any RadioBrowserServing) { self.directory = directory }

    func explore() async throws -> [Station] {
        StationRanker.group(try await directory.stations(matching: RadioBrowserQuery(
            field: nil, value: "", limit: 100, order: "clickcount", reverse: true
        )))
    }

    func search(_ query: String) async throws -> [Station] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return try await explore() }
        try Task.checkCancellation()
        async let names = request(.name, value)
        async let countries = request(.country, value)
        async let languages = request(.language, value)
        async let tags = request(.tag, value)
        let batches = try await [names, countries, languages, tags]
        try Task.checkCancellation()
        var unique: [UUID: Station] = [:]
        for station in batches.flatMap({ $0 }) where unique[station.id] == nil {
            unique[station.id] = station
        }
        return StationRanker.group(Array(unique.values))
    }

    private func request(_ field: RadioBrowserQuery.Field, _ value: String) async throws -> [Station] {
        try await directory.stations(matching: RadioBrowserQuery(
            field: field, value: value, limit: 30, order: "votes", reverse: true
        ))
    }
}
