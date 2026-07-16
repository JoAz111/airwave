import SwiftUI

struct NowPlayingBar: View {
    let model: AppModel
    let artwork: ArtworkLoader
    let transitionNamespace: Namespace.ID
    let onArtworkTap: () -> Void
    @State private var isArtworkHovering = false

    var body: some View {
        HStack(spacing: 12) {
            if let station = model.currentStation {
                Button(action: onArtworkTap) {
                    StationArtworkView(station: station, loader: artwork, size: 46)
                        .matchedGeometryEffect(
                            id: "now-playing-artwork",
                            in: transitionNamespace
                        )
                        .overlay {
                            if isArtworkHovering {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(.black.opacity(0.48))
                                    .overlay {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                            }
                        }
                }
                .buttonStyle(.plain)
                .onHover { isArtworkHovering = $0 }
                .help("Expand player")
                .accessibilityLabel("Expand now playing")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.currentStation?.name ?? "Choose a station")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(model.metadata?.displayText ?? stateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button { model.togglePlayback() } label: {
                ZStack {
                    Image(systemName: model.playbackState == .playing ? "pause.fill" : "play.fill")
                        .opacity(isBuffering ? 0 : 1)
                    if isBuffering {
                        ProgressView().controlSize(.small)
                    }
                }
                .font(.system(size: 15, weight: .bold))
                .frame(width: 18, height: 18)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .tint(.black)
            .disabled(model.currentStation == nil)
            .help("Play or pause")
            .accessibilityLabel(model.playbackState == .playing ? "Pause" : "Play")

            Divider().frame(height: 24)
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            PlayerVolumeSlider(model: model)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: 640)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
        .fixedSize(horizontal: false, vertical: true)
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

struct PlayerVolumeSlider: View {
    let model: AppModel

    var body: some View {
        Slider(
            value: Binding(
                get: { Double(model.volume) },
                set: { model.volume = Float($0) }
            ),
            in: 0 ... 1
        )
        .controlSize(.small)
        .frame(width: 96)
        .accessibilityLabel("Volume")
        .accessibilityIdentifier("player.volume")
    }
}
