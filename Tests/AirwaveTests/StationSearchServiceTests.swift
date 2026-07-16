import Foundation
import Testing
@testable import Airwave

struct StationSearchServiceTests {
    @Test
    func exploreUsesLocaleCountryCode() async throws {
        let directory = DirectoryFake(stations: [Self.station])
        let service = StationSearchService(directory: directory)

        _ = try await service.explore(countryCode: "IL")

        let queries = await directory.queries
        #expect(queries.count == 1)
        #expect(queries[0].field == nil)
        #expect(queries[0].countryCode == "IL")
        #expect(queries[0].limit == 100)
        #expect(queries[0].order == "clickcount")
    }

    @Test
    func globalSearchDoesNotQueryCountries() async throws {
        let directory = DirectoryFake(stations: [Self.station])
        let service = StationSearchService(directory: directory)

        let stations = try await service.search("jazz")

        #expect(stations.count == 1)
        #expect(Set(await directory.queries.compactMap(\.field)) == Set([.name, .language, .tag]))
        #expect(await directory.queries.allSatisfy { $0.countryCode == nil })
    }

    @Test
    func selectedCountrySearchConstrainsEveryRequest() async throws {
        let directory = DirectoryFake(stations: [Self.station])
        let service = StationSearchService(directory: directory)

        _ = try await service.stations(in: "IL", matching: "jazz")

        #expect(await directory.queries.count == 3)
        #expect(await directory.queries.allSatisfy { $0.countryCode == "IL" })
    }

    private static let station = Station(
        id: UUID(uuidString: "110e57c5-0601-11e8-ae97-52543be04c81")!,
        name: "Jazz FM",
        country: "United Kingdom",
        countryCode: "GB",
        tags: ["jazz"],
        homepageURL: URL(string: "https://example.com"),
        faviconURL: nil,
        sources: [StationSource(url: URL(string: "https://example.com/live")!, codec: "MP3", bitrate: 192, isHLS: false)],
        votes: 10
    )
}

private actor DirectoryFake: RadioBrowserServing {
    private(set) var queries: [RadioBrowserQuery] = []
    let stationsToReturn: [Station]

    init(stations: [Station]) { stationsToReturn = stations }

    func stations(matching query: RadioBrowserQuery) async throws -> [Station] {
        queries.append(query)
        return stationsToReturn
    }

    func countryCodes() async throws -> [CountryDirectoryEntry] { [] }

    func recordClick(stationID: UUID) async {}
}
