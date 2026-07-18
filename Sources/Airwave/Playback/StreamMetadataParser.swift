import AVFoundation
import Foundation

/// The small, sendable metadata representation that crosses AVFoundation's callback boundary.
struct MetadataValue: Equatable, Sendable {
    let identifier: String?
    let commonKey: String?
    let stringValue: String?
}

enum StreamMetadataParser {
    /// Converts common and ICY metadata into display-safe live track information without guessing.
    static func parse(_ values: [MetadataValue]) -> NowPlayingMetadata? {
        let cleaned = values.compactMap { value -> (MetadataValue, String)? in
            guard let text = value.stringValue?
                .components(separatedBy: .controlCharacters).joined()
                .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return (value, text)
        }
        guard !cleaned.isEmpty else { return nil }

        let title = cleaned.first { $0.0.commonKey == AVMetadataKey.commonKeyTitle.rawValue }?.1
        let artist = cleaned.first { $0.0.commonKey == AVMetadataKey.commonKeyArtist.rawValue }?.1
        if let title {
            return NowPlayingMetadata(title: title, artist: artist, displayText: artist.map { "\($0) — \(title)" } ?? title)
        }

        let raw = cleaned.first { $0.0.identifier == AVMetadataIdentifier.icyMetadataStreamTitle.rawValue }?.1 ?? cleaned[0].1
        let parts = raw.components(separatedBy: " - ")
        if parts.count == 2 {
            let artist = parts[0].trimmingCharacters(in: .whitespaces)
            let title = parts[1].trimmingCharacters(in: .whitespaces)
            if !artist.isEmpty, !title.isEmpty {
                return NowPlayingMetadata(title: title, artist: artist, displayText: "\(artist) — \(title)")
            }
        }
        return NowPlayingMetadata(title: nil, artist: nil, displayText: raw)
    }
}
