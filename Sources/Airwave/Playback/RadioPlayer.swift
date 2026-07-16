import AVFoundation
import Foundation
import OSLog

struct SourceQueue {
    private var remaining: ArraySlice<StationSource>
    init(sources: [StationSource]) { remaining = ArraySlice(sources) }
    mutating func next() -> StationSource? {
        guard let first = remaining.first else { return nil }
        remaining = remaining.dropFirst()
        return first
    }
}

@MainActor protocol RadioPlaying: AnyObject {
    var state: PlaybackState { get }
    var metadata: NowPlayingMetadata? { get }
    var volume: Float { get set }
    var onStateChange: ((PlaybackState) -> Void)? { get set }
    var onMetadataChange: ((NowPlayingMetadata?) -> Void)? { get set }
    func load(_ station: Station)
    func play()
    func pause()
    func stop()
}

@MainActor final class RadioPlayer: RadioPlaying {
    private let player = AVPlayer()
    private var sourceQueue = SourceQueue(sources: [])
    private var playerObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var metadataOutput: AVPlayerItemMetadataOutput?
    private var metadataDelegate: MetadataDelegate?
    private let logger = Logger(subsystem: "com.joeyazizoff.Airwave", category: "Playback")

    private(set) var state: PlaybackState = .idle { didSet { onStateChange?(state) } }
    private(set) var metadata: NowPlayingMetadata? { didSet { onMetadataChange?(metadata) } }
    var onStateChange: ((PlaybackState) -> Void)?
    var onMetadataChange: ((NowPlayingMetadata?) -> Void)?
    var volume: Float {
        get { player.volume }
        set { player.volume = min(1, max(0, newValue)) }
    }

    init() {
        playerObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }
                switch player.timeControlStatus {
                case .playing: self.state = .playing
                case .paused: if self.state != .idle && !self.isFailed { self.state = .paused }
                case .waitingToPlayAtSpecifiedRate: self.state = .waiting
                @unknown default: self.state = .waiting
                }
            }
        }
    }

    private var isFailed: Bool { if case .failed = state { return true }; return false }

    func load(_ station: Station) {
        metadata = nil
        sourceQueue = SourceQueue(sources: station.sources)
        loadNextSource()
    }

    func play() { player.play() }
    func pause() { player.pause() }
    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        state = .idle
        metadata = nil
    }

    private func loadNextSource() {
        guard let source = sourceQueue.next() else {
            state = .failed("This station is unavailable.")
            return
        }
        state = .loading
        let item = AVPlayerItem(url: source.url)
        attachMetadata(to: item)
        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self, item.status == .failed else { return }
                self.logger.notice("Stream source failed; trying fallback")
                self.loadNextSource()
            }
        }
        player.replaceCurrentItem(with: item)
        player.play()
    }

    private func attachMetadata(to item: AVPlayerItem) {
        let output = AVPlayerItemMetadataOutput(identifiers: nil)
        let delegate = MetadataDelegate { [weak self] values in
            Task { @MainActor in self?.metadata = StreamMetadataParser.parse(values) }
        }
        output.setDelegate(delegate, queue: .main)
        item.add(output)
        metadataOutput = output
        metadataDelegate = delegate
    }
}

private final class MetadataDelegate: NSObject, AVPlayerItemMetadataOutputPushDelegate, @unchecked Sendable {
    private let handler: @Sendable ([MetadataValue]) -> Void
    init(handler: @escaping @Sendable ([MetadataValue]) -> Void) { self.handler = handler }

    func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: sending [AVTimedMetadataGroup], from track: AVPlayerItemTrack?) {
        let items = groups.flatMap(\.items)
        Task {
            var values: [MetadataValue] = []
            for item in items {
                values.append(MetadataValue(
                    identifier: item.identifier?.rawValue,
                    commonKey: item.commonKey?.rawValue,
                    stringValue: try? await item.load(.stringValue)
                ))
            }
            handler(values)
        }
    }
}
