import Foundation

/// The intentionally small preference payload stored locally on the user's Mac.
struct AirwavePreferences: Codable, Equatable, Sendable {
    static let currentSchema = 1
    var schemaVersion = currentSchema
    var favorites: [Station] = []
    var recents: [Station] = []
    var lastStation: Station?
    var volume: Float = 0.7

    /// Clamps persisted values and keeps recents from becoming an unbounded collection.
    mutating func normalize() {
        volume = min(1, max(0, volume))
        recents = Array(recents.prefix(25))
    }
}

/// Persistence boundary used by the app model and lightweight test doubles.
@MainActor protocol PreferencesStoring: AnyObject {
    /// Restores normalized preferences or returns first-launch defaults.
    func load() -> AirwavePreferences
    /// Persists a normalized preference snapshot.
    func save(_ preferences: AirwavePreferences)
}

/// UserDefaults-backed local storage with a versioned JSON payload.
@MainActor final class PreferencesStore: PreferencesStoring {
    private let defaults: UserDefaults
    private let key = "airwave.preferences.v1"

    /// Creates a store with injectable defaults for tests and previews.
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// Restores only the current preference schema and otherwise starts clean.
    func load() -> AirwavePreferences {
        guard let data = defaults.data(forKey: key),
              var value = try? JSONDecoder().decode(AirwavePreferences.self, from: data),
              value.schemaVersion == AirwavePreferences.currentSchema else {
            return AirwavePreferences()
        }
        value.normalize()
        return value
    }

    /// Normalizes and serializes the lightweight preference snapshot.
    func save(_ preferences: AirwavePreferences) {
        var value = preferences
        value.normalize()
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
