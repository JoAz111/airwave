import Foundation
import Testing
@testable import Airwave

struct CountryCatalogTests {
    private let locale = Locale(identifier: "en_US")

    @Test
    func pinsLocaleCountryThenSortsTheRemainder() {
        let countries = CountryCatalog.make(
            entries: [
                CountryDirectoryEntry(code: "DE", stationCount: 8),
                CountryDirectoryEntry(code: "IL", stationCount: 4),
                CountryDirectoryEntry(code: "FR", stationCount: 6)
            ],
            locale: locale,
            localCode: "IL"
        )

        #expect(countries.map(\.code) == ["IL", "FR", "DE"])
        #expect(countries.first?.isLocal == true)
        #expect(countries.dropFirst().allSatisfy { !$0.isLocal })
    }

    @Test
    func flagsUseRegionalIndicatorSymbols() {
        let country = Country(
            code: "IL",
            name: "Israel",
            stationCount: 4,
            isLocal: true
        )

        #expect(country.flag == "🇮🇱")
    }

    @Test
    func filtersByLocalizedNameOrCode() {
        let countries = CountryCatalog.make(
            entries: [
                CountryDirectoryEntry(code: "DE", stationCount: 8),
                CountryDirectoryEntry(code: "FR", stationCount: 6)
            ],
            locale: locale,
            localCode: nil
        )

        #expect(CountryCatalog.filter(countries, query: "fr").map(\.code) == ["FR"])
        #expect(CountryCatalog.filter(countries, query: "germ").map(\.code) == ["DE"])
    }

    @Test
    func fallbackContainsOnlyTwoLetterRegions() {
        let countries = CountryCatalog.fallback(locale: locale, localCode: "US")

        #expect(countries.first?.code == "US")
        #expect(countries.allSatisfy { $0.code.count == 2 })
    }
}
