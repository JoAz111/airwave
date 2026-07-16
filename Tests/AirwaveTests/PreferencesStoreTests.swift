import Foundation
import Testing
@testable import Airwave

@MainActor struct PreferencesStoreTests {
    @Test func roundTripsAndNormalizesPreferences() throws {
        let suite = "AirwaveTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults)
        var value = AirwavePreferences()
        value.volume = 2
        value.recents = Array(repeating: Self.station, count: 30)
        value.favorites = [Self.station]
        value.lastStation = Self.station

        store.save(value)
        let loaded = store.load()

        #expect(loaded.volume == 1)
        #expect(loaded.recents.count == 25)
        #expect(loaded.favorites == [Self.station])
        #expect(loaded.lastStation == Self.station)
    }

    private static let station = Station(id: UUID(), name: "FIP", country: "France", countryCode: "FR", tags: [], homepageURL: nil, faviconURL: nil, sources: [StationSource(url: URL(string: "https://example.com/live")!, codec: "AAC", bitrate: 192, isHLS: false)], votes: 1)
}
