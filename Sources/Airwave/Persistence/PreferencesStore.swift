import Foundation

struct AirwavePreferences: Codable, Equatable, Sendable {
    static let currentSchema = 1
    var schemaVersion = currentSchema
    var favorites: [Station] = []
    var recents: [Station] = []
    var lastStation: Station?
    var volume: Float = 0.7

    mutating func normalize() {
        volume = min(1, max(0, volume))
        recents = Array(recents.prefix(25))
    }
}

@MainActor protocol PreferencesStoring: AnyObject {
    func load() -> AirwavePreferences
    func save(_ preferences: AirwavePreferences)
}

@MainActor final class PreferencesStore: PreferencesStoring {
    private let defaults: UserDefaults
    private let key = "airwave.preferences.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> AirwavePreferences {
        guard let data = defaults.data(forKey: key),
              var value = try? JSONDecoder().decode(AirwavePreferences.self, from: data),
              value.schemaVersion == AirwavePreferences.currentSchema else {
            return AirwavePreferences()
        }
        value.normalize()
        return value
    }

    func save(_ preferences: AirwavePreferences) {
        var value = preferences
        value.normalize()
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
