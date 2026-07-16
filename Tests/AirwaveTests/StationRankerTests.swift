import Foundation
import Testing
@testable import Airwave

struct StationRankerTests {
    @Test
    func ranksPlausibleHighBitrateBeforeLowerBitrate() {
        let low = station(name: "Low", bitrate: 128)
        let high = station(name: "High", bitrate: 320)

        #expect(StationRanker.rank([low, high]).map(\.name) == ["High", "Low"])
    }

    @Test
    func prefersHTTPSAtEqualBitrate() {
        let http = station(name: "HTTP", url: "http://example.com/live", bitrate: 192)
        let https = station(name: "HTTPS", url: "https://example.com/live", bitrate: 192)

        #expect(StationRanker.rank([http, https]).first?.name == "HTTPS")
    }

    @Test
    func groupsMatchingStationsAndKeepsSourcesOrdered() {
        let low = station(name: "FIP", url: "https://one.example/live", bitrate: 128)
        let high = station(name: "fip", url: "https://two.example/live", bitrate: 320)

        let grouped = StationRanker.group([low, high])

        #expect(grouped.count == 1)
        #expect(grouped[0].sources.map(\.bitrate) == [320, 128])
    }

    @Test
    func leavesStationSeparateWithoutHomepageHost() {
        let first = station(name: "Radio One", homepageURL: nil)
        let second = station(name: "Radio One", homepageURL: nil)

        #expect(StationRanker.group([first, second]).count == 2)
    }

    private func station(
        name: String,
        url: String = "https://example.com/live",
        bitrate: Int? = 128,
        homepageURL: URL? = URL(string: "https://station.example")
    ) -> Station {
        Station(
            id: UUID(),
            name: name,
            country: "France",
            countryCode: "FR",
            tags: [],
            homepageURL: homepageURL,
            faviconURL: nil,
            sources: [
                StationSource(
                    url: URL(string: url)!,
                    codec: "AAC",
                    bitrate: bitrate,
                    isHLS: false
                )
            ],
            votes: 10
        )
    }
}
