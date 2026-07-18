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
    func stoppingRadioAndPlayingAgainReloadsTheLiveStream() {
        let player = PlayerFake()
        let model = AppModel(
            search: SearchFake(),
            countries: CountryFake(values: []),
            player: player,
            preferences: PreferencesFake(value: AirwavePreferences())
        )

        model.select(Self.station)
        model.togglePlayback()

        #expect(player.stopCount == 1)
        #expect(model.playbackState == .idle)

        model.togglePlayback()

        #expect(player.loaded == [Self.station, Self.station])
        #expect(model.playbackState == .playing)
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

    @Test
    func ignoresAnOlderSearchThatFinishesAfterANewerQuery() async throws {
        let oldStation = Self.station
        let newStation = Self.otherStation
        let search = SearchRaceFake(oldStation: oldStation, newStation: newStation)
        let model = makeModel(search: search)

        model.updateQuery("old")
        try await waitForOldSearch(search)

        model.updateQuery("new")
        try await Task.sleep(for: .milliseconds(360))
        #expect(model.visibleStations.map(\.id) == [newStation.id])

        await search.completeOldSearch()
        try await Task.sleep(for: .milliseconds(40))

        #expect(model.visibleStations.map(\.id) == [newStation.id])
    }

    private func makeModel(
        search: any StationSearching = SearchFake(),
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

    private func waitForOldSearch(_ search: SearchRaceFake) async throws {
        for _ in 0 ..< 50 {
            if await search.hasPendingOldSearch { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("The old search never started")
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

private actor SearchRaceFake: StationSearching {
    private let oldStation: Station
    private let newStation: Station
    private var oldContinuation: CheckedContinuation<[Station], Never>?

    init(oldStation: Station, newStation: Station) {
        self.oldStation = oldStation
        self.newStation = newStation
    }

    var hasPendingOldSearch: Bool { oldContinuation != nil }

    func explore(countryCode: String?) async throws -> [Station] { [] }

    func search(_ query: String) async throws -> [Station] {
        if query == "old" {
            return await withCheckedContinuation { continuation in
                oldContinuation = continuation
            }
        }
        return query == "new" ? [newStation] : []
    }

    func stations(in countryCode: String, matching query: String) async throws -> [Station] { [] }

    func completeOldSearch() {
        oldContinuation?.resume(returning: [oldStation])
        oldContinuation = nil
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
    var stopCount = 0

    func load(_ station: Station) {
        loaded.append(station)
        state = .playing
        onStateChange?(.playing)
    }
    func stop() {
        stopCount += 1
        state = .idle
        onStateChange?(.idle)
    }
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
