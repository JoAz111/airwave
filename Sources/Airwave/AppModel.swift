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
    private var searchGeneration = 0
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
            StationRanker.group(localFilter(favorites))
        case .recent:
            StationRanker.group(localFilter(recents))
        }
    }

    var searchPlaceholder: String {
        switch libraryMode {
        case .explore:
            "Search radio"
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

    var isPlaybackActive: Bool {
        switch playbackState {
        case .loading, .playing, .waiting:
            true
        case .idle, .paused, .failed:
            false
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

    /// Loads the first locale-ranked station collection once per app launch.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await performStationSearch()
    }

    /// Restarts the current remote station request after an error.
    func retry() {
        cancelPendingSearch()
        Task { await performStationSearch() }
    }

    /// Selects a library section and loads the data that section needs.
    func activate(_ mode: LibraryMode) async {
        cancelPendingSearch()
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

    /// Updates the visible query and debounces only remote station searches.
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

    /// Enters a country and starts its station collection from a clean search state.
    func selectCountry(_ country: Country) async {
        cancelPendingSearch()
        countryListQuery = query
        selectedCountry = country
        query = ""
        stations = []
        await performStationSearch()
    }

    /// Returns to the country collection while restoring its prior query.
    func backToCountries() {
        cancelPendingSearch()
        selectedCountry = nil
        stations = []
        query = countryListQuery
        errorMessage = nil
        isLoading = false
    }

    /// Starts a station and persists it as the most recent selection.
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

    /// Adds or removes a station from the persisted favorites collection.
    func toggleFavorite(_ station: Station) {
        if let index = favorites.firstIndex(where: { $0.id == station.id }) {
            favorites.remove(at: index)
        } else {
            favorites.append(station)
        }
        preferences.favorites = favorites
        preferencesStore.save(preferences)
    }

    /// Reports whether a station belongs to the favorites collection.
    func isFavorite(_ station: Station) -> Bool {
        favorites.contains { $0.id == station.id }
    }

    /// Stops a live stream, or reloads the selected station from live when stopped.
    func togglePlayback() {
        if isPlaybackActive {
            player.stop()
        } else if let currentStation {
            metadata = nil
            player.load(currentStation)
        }
    }

    /// Filters persisted collections without creating a directory request.
    private func localFilter(_ values: [Station]) -> [Station] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return values }
        return values.filter { station in
            station.name.localizedCaseInsensitiveContains(value)
                || (station.country?.localizedCaseInsensitiveContains(value) == true)
                || station.tags.contains { $0.localizedCaseInsensitiveContains(value) }
        }
    }

    /// Debounces a remote search and invalidates any response already in flight.
    private func scheduleSearch() {
        cancelPendingSearch()
        let generation = searchGeneration
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.performStationSearch(generation: generation)
        }
    }

    /// Cancels scheduled work and makes any earlier response ineligible to mutate UI state.
    private func cancelPendingSearch() {
        searchTask?.cancel()
        searchTask = nil
        searchGeneration &+= 1
    }

    /// Fetches stations for the active section while discarding stale responses.
    private func performStationSearch(generation: Int? = nil) async {
        guard libraryMode == .explore
                || (libraryMode == .countries && selectedCountry != nil) else {
            return
        }
        let requestGeneration: Int
        if let generation {
            guard generation == searchGeneration else { return }
            requestGeneration = generation
        } else {
            searchGeneration &+= 1
            requestGeneration = searchGeneration
        }
        isLoading = true
        errorMessage = nil
        defer {
            if requestGeneration == searchGeneration {
                isLoading = false
            }
        }

        do {
            let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let results: [Station]
            switch libraryMode {
            case .explore where value.isEmpty:
                results = try await searchService.explore(countryCode: localCountryCode)
            case .explore:
                results = try await searchService.search(value)
            case .countries:
                guard let selectedCountry else { return }
                results = try await searchService.stations(
                    in: selectedCountry.code,
                    matching: value
                )
            case .favorites, .recent:
                return
            }
            guard requestGeneration == searchGeneration, !Task.isCancelled else { return }
            stations = results
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == searchGeneration, !Task.isCancelled else { return }
            errorMessage = "Couldn’t load stations. Check your connection and try again."
        }
    }
}
