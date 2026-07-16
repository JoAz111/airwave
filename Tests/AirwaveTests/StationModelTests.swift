import Foundation
import Testing
@testable import Airwave

struct StationModelTests {
    @Test
    func stationRoundTripsThroughJSON() throws {
        let station = Station(
            id: UUID(uuidString: "110e57c5-0601-11e8-ae97-52543be04c81")!,
            name: "FIP",
            country: "France",
            countryCode: "FR",
            tags: ["eclectic", "jazz"],
            homepageURL: URL(string: "https://www.radiofrance.fr/fip"),
            faviconURL: URL(string: "https://example.com/fip.png"),
            sources: [
                StationSource(
                    url: URL(string: "https://example.com/fip.aac")!,
                    codec: "AAC",
                    bitrate: 192,
                    isHLS: false
                )
            ],
            votes: 42
        )

        let data = try JSONEncoder().encode(station)
        let decoded = try JSONDecoder().decode(Station.self, from: data)

        #expect(decoded == station)
        #expect(decoded.primarySource?.bitrate == 192)
    }

    @Test
    func metadataUsesRawTextWhenNoStructuredFieldsExist() {
        let metadata = NowPlayingMetadata(title: nil, artist: nil, displayText: "The Morning Exchange")

        #expect(metadata.displayText == "The Morning Exchange")
    }
}
