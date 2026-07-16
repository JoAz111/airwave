import Foundation

struct StationSource: Codable, Hashable, Sendable {
    let url: URL
    let codec: String?
    let bitrate: Int?
    let isHLS: Bool
}

struct Station: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let country: String?
    let countryCode: String?
    let tags: [String]
    let homepageURL: URL?
    let faviconURL: URL?
    var sources: [StationSource]
    var votes: Int

    var primarySource: StationSource? {
        sources.first
    }
}

enum PlaybackState: Equatable, Sendable {
    case idle
    case loading
    case playing
    case paused
    case waiting
    case failed(String)
}

struct NowPlayingMetadata: Codable, Equatable, Sendable {
    let title: String?
    let artist: String?
    let displayText: String
}

enum LibraryMode: String, CaseIterable, Identifiable, Sendable {
    case explore = "Explore"
    case favorites = "Favorites"
    case recent = "Recent"

    var id: Self { self }
}
