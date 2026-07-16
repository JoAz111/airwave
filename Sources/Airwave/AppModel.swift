import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private let searchService: any StationSearching
    private let countryService: any CountryLoading
    private let player: any RadioPlaying
    private let preferencesStore: any PreferencesStoring
    private let locale: Locale
    private let localCountryCode: String?
    private var preferences: AirwavePreferences
    private var searchTask: Task<Void, Never>?
    private var countryListQuery = ""
    private var hasStarted = false

    private(set) var stations: [Station] = []
    private(set) var countries: [Country] = []
    private(set) var favorites: [Station]
    private(set) var recents: [Station]
    private(set) var currentStation: Station?
    private(set) var selectedCountry: Country?
    private(set) var playbackState: PlaybackState = .idle
    private(set) var metadata: NowPlayingMetadata?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var libraryMode: LibraryMode = .explore
    var volume: Float {
        didSet {
            let clampedVolume = min(1, max(0, volume))
            player.volume = clampedVolume
            preferences.volume = clampedVolume
            preferencesStore.save(preferences)
        }
    }
    var query = ""

    var visibleCountries: [Country] {
        CountryCatalog.filter(countries, query: selectedCountry == nil ? query : "")
    }

    var visibleStations: [Station] {
        switch libraryMode {
        case .explore:
            stations
        case .countries:
            selectedCountry == nil ? [] : stations
        case .favorites:
            localFilter(favorites)
        case .recent:
            localFilter(recents)
        }
    }

    var searchPlaceholder: String {
        switch libraryMode {
        case .explore:
            "Search stations, languages, or genres"
        case .countries where selectedCountry == nil:
            "Search countries"
        case .countries:
            "Search stations in \(selectedCountry?.name ?? "country")"
        case .favorites:
            "Search favorites"
        case .recent:
            "Search recent stations"
        }
    }

    init(
        search: any StationSearching,
        countries: any CountryLoading,
        player: any RadioPlaying,
        preferences: any PreferencesStoring,
        locale: Locale = .autoupdatingCurrent,
        localCountryCode: String? = Locale.autoupdatingCurrent.region?.identifier
    ) {
        searchService = search
        countryService = countries
        self.player = player
        preferencesStore = preferences
        self.locale = locale
        self.localCountryCode = localCountryCode?.uppercased()
        let saved = preferences.load()
        self.preferences = saved
        volume = saved.volume
        favorites = saved.favorites
        recents = saved.recents
        currentStation = saved.lastStation
        player.volume = volume
        player.onStateChange = { [weak self] in self?.playbackState = $0 }
        player.onMetadataChange = { [weak self] in self?.metadata = $0 }
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await performStationSearch()
    }

    func retry() {
        Task { await performStationSearch() }
    }

    func activate(_ mode: LibraryMode) async {
        searchTask?.cancel()
        libraryMode = mode
        query = mode == .countries && selectedCountry == nil ? countryListQuery : ""
        errorMessage = nil

        if mode == .countries, countries.isEmpty {
            isLoading = true
            countries = await countryService.load(
                locale: locale,
                localCode: localCountryCode
            )
            isLoading = false
        }

        if mode == .explore {
            await performStationSearch()
        }
    }

    func updateQuery(_ value: String) {
        query = value
        switch libraryMode {
        case .explore:
            scheduleSearch()
        case .countries where selectedCountry != nil:
            scheduleSearch()
        case .countries, .favorites, .recent:
            break
        }
    }

    func selectCountry(_ country: Country) async {
        searchTask?.cancel()
        countryListQuery = query
        selectedCountry = country
        query = ""
        stations = []
        await performStationSearch()
    }

    func backToCountries() {
        searchTask?.cancel()
        selectedCountry = nil
        stations = []
        query = countryListQuery
        errorMessage = nil
        isLoading = false
    }

    func select(_ station: Station) {
        currentStation = station
        metadata = nil
        recents.removeAll { $0.id == station.id }
        recents.insert(station, at: 0)
        recents = Array(recents.prefix(25))
        preferences.recents = recents
        preferences.lastStation = station
        preferencesStore.save(preferences)
        player.load(station)
    }

    func toggleFavorite(_ station: Station) {
        if let index = favorites.firstIndex(where: { $0.id == station.id }) {
            favorites.remove(at: index)
        } else {
            favorites.append(station)
        }
        preferences.favorites = favorites
        preferencesStore.save(preferences)
    }

    func isFavorite(_ station: Station) -> Bool {
        favorites.contains { $0.id == station.id }
    }

    func togglePlayback() {
        playbackState == .playing ? player.pause() : player.play()
    }

    private func localFilter(_ values: [Station]) -> [Station] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return values }
        return values.filter { station in
            station.name.localizedCaseInsensitiveContains(value)
                || (station.country?.localizedCaseInsensitiveContains(value) == true)
                || station.tags.contains { $0.localizedCaseInsensitiveContains(value) }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.performStationSearch()
        }
    }

    private func performStationSearch() async {
        guard libraryMode == .explore
                || (libraryMode == .countries && selectedCountry != nil) else {
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
            switch libraryMode {
            case .explore where value.isEmpty:
                stations = try await searchService.explore(countryCode: localCountryCode)
            case .explore:
                stations = try await searchService.search(value)
            case .countries:
                guard let selectedCountry else { return }
                stations = try await searchService.stations(
                    in: selectedCountry.code,
                    matching: value
                )
            case .favorites, .recent:
                return
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "Couldn’t load stations. Check your connection and try again."
        }
    }
}
