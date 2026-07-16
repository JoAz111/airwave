import SwiftUI

struct NowPlayingBar: View {
    let model: AppModel
    let artwork: ArtworkLoader

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 10) {
                if let station = model.currentStation {
                    StationArtworkView(station: station, loader: artwork, size: 42)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.currentStation?.name ?? "Choose a station")
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(model.metadata?.displayText ?? stateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Button { model.togglePlayback() } label: {
                    ZStack {
                        Image(systemName: model.playbackState == .playing ? "pause.fill" : "play.fill")
                            .opacity(isBuffering ? 0 : 1)
                        if isBuffering {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 34, height: 34)
                    .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .disabled(model.currentStation == nil)
                .help("Play or pause")
                .accessibilityLabel(model.playbackState == .playing ? "Pause" : "Play")
                Slider(
                    value: Binding(
                        get: { Double(model.volume) },
                        set: { model.volume = Float($0) }
                    ),
                    in: 0 ... 1
                )
                .frame(width: 88)
                .accessibilityLabel("Volume")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
        }
    }

    private var isBuffering: Bool {
        model.playbackState == .loading || model.playbackState == .waiting
    }

    private var stateText: String {
        switch model.playbackState {
        case .loading, .waiting: "Buffering…"
        case .playing: "Playing live"
        case .failed(let text): text
        default: "Live broadcast"
        }
    }
}
