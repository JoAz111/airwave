import AVFoundation
import Testing
@testable import Airwave

struct StreamMetadataParserTests {
    @Test func splitsOneClearArtistTitlePair() {
        let result = StreamMetadataParser.parse([MetadataValue(identifier: AVMetadataIdentifier.icyMetadataStreamTitle.rawValue, commonKey: nil, stringValue: "Massive Attack - Teardrop")])
        #expect(result == NowPlayingMetadata(title: "Teardrop", artist: "Massive Attack", displayText: "Massive Attack — Teardrop"))
    }

    @Test func preservesShowNameWithoutGuessing() {
        let result = StreamMetadataParser.parse([MetadataValue(identifier: nil, commonKey: nil, stringValue: "The Morning Exchange")])
        #expect(result?.displayText == "The Morning Exchange")
        #expect(result?.artist == nil)
    }

    @Test func blankMetadataIsAbsent() {
        #expect(StreamMetadataParser.parse([MetadataValue(identifier: nil, commonKey: nil, stringValue: "  ")]) == nil)
    }
}
