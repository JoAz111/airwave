import Foundation
import Testing
@testable import Airwave

@MainActor struct RadioPlayerTests {
    @Test func sourceQueueAdvancesThroughFallbacksOnce() {
        var queue = SourceQueue(sources: [
            StationSource(url: URL(string: "https://one.example/live")!, codec: nil, bitrate: 320, isHLS: false),
            StationSource(url: URL(string: "https://two.example/live")!, codec: nil, bitrate: 192, isHLS: false)
        ])
        #expect(queue.next()?.url.host == "one.example")
        #expect(queue.next()?.url.host == "two.example")
        #expect(queue.next() == nil)
    }

    @Test func volumeClampsToPlayerRange() {
        let player = RadioPlayer()
        player.volume = 2
        #expect(player.volume == 1)
        player.volume = -1
        #expect(player.volume == 0)
    }
}
