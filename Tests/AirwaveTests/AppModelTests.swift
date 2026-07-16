import Foundation
import Testing
@testable import Airwave

@MainActor struct AppModelTests {
    @Test func restoresWithoutAutoplayAndSelectsIntoRecents() async {
        let station = Station(id: UUID(), name: "FIP", country: "France", countryCode: "FR", tags: [], homepageURL: nil, faviconURL: nil, sources: [StationSource(url: URL(string: "https://example.com/live")!, codec: "AAC", bitrate: 192, isHLS: false)], votes: 1)
        let player = PlayerFake()
        let preferences = PreferencesFake(value: AirwavePreferences(favorites: [], recents: [], lastStation: station, volume: 0.4))
        let model = AppModel(search: SearchFake(), player: player, preferences: preferences)

        #expect(model.currentStation == station)
        #expect(player.loaded.isEmpty)
        model.select(station)
        #expect(player.loaded == [station])
        #expect(model.recents == [station])
    }
}

private actor SearchFake: StationSearching {
    func explore() async throws -> [Station] { [] }
    func search(_ query: String) async throws -> [Station] { [] }
}

@MainActor private final class PlayerFake: RadioPlaying {
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

@MainActor private final class PreferencesFake: PreferencesStoring {
    var value: AirwavePreferences
    init(value: AirwavePreferences) { self.value = value }
    func load() -> AirwavePreferences { value }
    func save(_ preferences: AirwavePreferences) { value = preferences }
}
