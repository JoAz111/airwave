import Foundation
import Testing
@testable import Airwave

@MainActor
struct AppModelTests {
    @Test
    func restoresWithoutAutoplayAndSelectsIntoRecents() async {
        let station = Self.station
        let player = PlayerFake()
        let preferences = PreferencesFake(value: AirwavePreferences(
            favorites: [],
            recents: [],
            lastStation: station,
            volume: 0.4
        ))
        let model = AppModel(
            search: SearchFake(),
            countries: CountryFake(values: []),
            player: player,
            preferences: preferences,
            locale: Locale(identifier: "en_IL"),
            localCountryCode: "IL"
        )

        #expect(model.currentStation == station)
        #expect(player.loaded.isEmpty)
        model.select(station)
        #expect(player.loaded == [station])
        #expect(model.recents == [station])
    }

    @Test
    func startsExploreWithLocaleCountry() async {
        let search = SearchFake()
        let model = makeModel(search: search)

        await model.start()

        #expect(await search.exploreCodes == ["IL"])
    }

    @Test
    func volumeUpdatesPlayerAndPreferences() {
        let player = PlayerFake()
        let preferences = PreferencesFake(value: AirwavePreferences(volume: 0.4))
        let model = AppModel(
            search: SearchFake(),
            countries: CountryFake(values: []),
            player: player,
            preferences: preferences
        )

        model.volume = 0.25

        #expect(model.volume == 0.25)
        #expect(player.volume == 0.25)
        #expect(preferences.value.volume == 0.25)
    }

    @Test
    func countriesTabPinsLocaleAndSearchesCountriesLocally() async {
        let values = [
            Country(code: "IL", name: "Israel", stationCount: 4, isLocal: true),
            Country(code: "FR", name: "France", stationCount: 6, isLocal: false)
        ]
        let model = makeModel(countries: values)

        await model.activate(.countries)
        model.updateQuery("fr")

        #expect(model.visibleCountries.map(\.code) == ["FR"])
        #expect(model.searchPlaceholder == "Search countries")
    }

    @Test
    func selectingAndLeavingCountryRestoresCountryQuery() async throws {
        let model = makeModel(countries: [
            Country(code: "FR", name: "France", stationCount: 6, isLocal: false)
        ])
        await model.activate(.countries)
        model.updateQuery("fr")

        await model.selectCountry(try #require(model.visibleCountries.first))

        #expect(model.selectedCountry?.code == "FR")
        #expect(model.query.isEmpty)
        #expect(model.searchPlaceholder == "Search stations in France")
        model.backToCountries()
        #expect(model.selectedCountry == nil)
        #expect(model.query == "fr")
    }

    @Test
    func favoritesSearchFiltersLocallyWithoutDirectoryRequest() async {
        var preferences = AirwavePreferences()
        preferences.favorites = [Self.station, Self.otherStation]
        let search = SearchFake()
        let model = makeModel(search: search, preferences: preferences)

        await model.activate(.favorites)
        model.updateQuery("fip")

        #expect(model.visibleStations.map(\.name) == ["FIP"])
        #expect(await search.globalQueries.isEmpty)
    }

    private func makeModel(
        search: SearchFake = SearchFake(),
        countries values: [Country] = [],
        preferences: AirwavePreferences = AirwavePreferences()
    ) -> AppModel {
        AppModel(
            search: search,
            countries: CountryFake(values: values),
            player: PlayerFake(),
            preferences: PreferencesFake(value: preferences),
            locale: Locale(identifier: "en_IL"),
            localCountryCode: "IL"
        )
    }

    private static let station = Station(
        id: UUID(),
        name: "FIP",
        country: "France",
        countryCode: "FR",
        tags: ["jazz"],
        homepageURL: nil,
        faviconURL: nil,
        sources: [StationSource(
            url: URL(string: "https://example.com/live")!,
            codec: "AAC",
            bitrate: 192,
            isHLS: false
        )],
        votes: 1
    )

    private static let otherStation = Station(
        id: UUID(),
        name: "NTS",
        country: "United Kingdom",
        countryCode: "GB",
        tags: ["electronic"],
        homepageURL: nil,
        faviconURL: nil,
        sources: [StationSource(
            url: URL(string: "https://example.com/nts")!,
            codec: "AAC",
            bitrate: 256,
            isHLS: false
        )],
        votes: 1
    )
}

private actor SearchFake: StationSearching {
    private(set) var exploreCodes: [String?] = []
    private(set) var globalQueries: [String] = []
    private(set) var countryQueries: [(String, String)] = []

    func explore(countryCode: String?) async throws -> [Station] {
        exploreCodes.append(countryCode)
        return []
    }

    func search(_ query: String) async throws -> [Station] {
        globalQueries.append(query)
        return []
    }

    func stations(in countryCode: String, matching query: String) async throws -> [Station] {
        countryQueries.append((countryCode, query))
        return []
    }
}

private actor CountryFake: CountryLoading {
    let values: [Country]

    init(values: [Country]) {
        self.values = values
    }

    func load(locale: Locale, localCode: String?) async -> [Country] {
        values
    }
}

@MainActor
private final class PlayerFake: RadioPlaying {
    var state: PlaybackState = .idle
    var metadata: NowPlayingMetadata?
    var volume: Float = 0
    var onStateChange: ((PlaybackState) -> Void)?
    var onMetadataChange: ((NowPlayingMetadata?) -> Void)?
    var loaded: [Station] = []

    func load(_ station: Station) { loaded.append(station) }
    func play() {}
    func pause() {}
    func stop() {}
}

@MainActor
private final class PreferencesFake: PreferencesStoring {
    var value: AirwavePreferences

    init(value: AirwavePreferences) {
        self.value = value
    }

    func load() -> AirwavePreferences { value }
    func save(_ preferences: AirwavePreferences) { value = preferences }
}
