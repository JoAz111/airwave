import Foundation
import Testing
@testable import Airwave

struct CountryServiceTests {
    @Test
    func loadsDirectoryCountriesWithLocaleFirst() async {
        let directory = CountryDirectoryFake(entries: [
            CountryDirectoryEntry(code: "FR", stationCount: 6),
            CountryDirectoryEntry(code: "IL", stationCount: 4)
        ])
        let service = CountryService(directory: directory)

        let countries = await service.load(
            locale: Locale(identifier: "en_US"),
            localCode: "IL"
        )

        #expect(countries.map(\.code) == ["IL", "FR"])
        #expect(countries.first?.stationCount == 4)
    }

    @Test
    func fallsBackToFoundationRegionsWhenDirectoryFails() async {
        let directory = CountryDirectoryFake(entries: [], shouldThrow: true)
        let service = CountryService(directory: directory)

        let countries = await service.load(
            locale: Locale(identifier: "en_US"),
            localCode: "US"
        )

        #expect(countries.first?.code == "US")
        #expect(countries.allSatisfy { $0.code.count == 2 })
    }
}

private actor CountryDirectoryFake: RadioBrowserServing {
    enum Failure: Error { case requested }

    let entries: [CountryDirectoryEntry]
    let shouldThrow: Bool

    init(entries: [CountryDirectoryEntry], shouldThrow: Bool = false) {
        self.entries = entries
        self.shouldThrow = shouldThrow
    }

    func stations(matching query: RadioBrowserQuery) async throws -> [Station] { [] }

    func countryCodes() async throws -> [CountryDirectoryEntry] {
        if shouldThrow { throw Failure.requested }
        return entries
    }

    func recordClick(stationID: UUID) async {}
}
