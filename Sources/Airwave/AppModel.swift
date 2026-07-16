import Foundation
import Observation

@MainActor @Observable final class AppModel {
    private let searchService: any StationSearching
    private let player: any RadioPlaying
    private let preferencesStore: any PreferencesStoring
    private var preferences: AirwavePreferences
    private var searchTask: Task<Void, Never>?

    private(set) var stations: [Station] = []
    private(set) var favorites: [Station]
    private(set) var recents: [Station]
    private(set) var currentStation: Station?
    private(set) var playbackState: PlaybackState = .idle
    private(set) var metadata: NowPlayingMetadata?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var libraryMode: LibraryMode = .explore
    var query = "" { didSet { scheduleSearch() } }

    var volume: Float {
        get { player.volume }
        set {
            player.volume = newValue
            preferences.volume = player.volume
            preferencesStore.save(preferences)
        }
    }

    var visibleStations: [Station] {
        switch libraryMode { case .explore: stations; case .favorites: favorites; case .recent: recents }
    }

    init(search: any StationSearching, player: any RadioPlaying, preferences: any PreferencesStoring) {
        searchService = search
        self.player = player
        preferencesStore = preferences
        let saved = preferences.load()
        self.preferences = saved
        favorites = saved.favorites
        recents = saved.recents
        currentStation = saved.lastStation
        player.volume = saved.volume
        player.onStateChange = { [weak self] in self?.playbackState = $0 }
        player.onMetadataChange = { [weak self] in self?.metadata = $0 }
    }

    func start() { Task { await performSearch() } }

    func retry() { Task { await performSearch() } }

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
        if let index = favorites.firstIndex(where: { $0.id == station.id }) { favorites.remove(at: index) }
        else { favorites.append(station) }
        preferences.favorites = favorites
        preferencesStore.save(preferences)
    }

    func isFavorite(_ station: Station) -> Bool { favorites.contains { $0.id == station.id } }
    func togglePlayback() { playbackState == .playing ? player.pause() : player.play() }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.performSearch()
        }
    }

    private func performSearch() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { stations = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? try await searchService.explore(countryCode: nil) : try await searchService.search(query) }
        catch is CancellationError { return }
        catch { errorMessage = "Couldn’t load stations. Check your connection and try again." }
    }
}
