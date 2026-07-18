import SwiftUI

struct NowPlayingBar: View {
    let model: AppModel
    let artwork: ArtworkLoader
    let onArtworkTap: () -> Void
    @State private var isArtworkHovering = false

    var body: some View {
        HStack(spacing: 12) {
            if let station = model.currentStation {
                Button(action: onArtworkTap) {
                    StationArtworkView(station: station, loader: artwork, size: 46)
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
                .accessibilityIdentifier("player.expand")
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
            PlayerPrimaryButton(
                isPlaybackActive: model.isPlaybackActive,
                isBuffering: isBuffering,
                diameter: 40,
                action: model.togglePlayback
            )
            .disabled(model.currentStation == nil)

            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            PlayerVolumeSlider(model: model)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: 590)
        .glassEffect(
            .regular.tint(.white.opacity(0.34)).interactive(),
            in: .rect(cornerRadius: 26)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, y: 6)
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
        case .idle, .paused: "Stopped"
        }
    }
}

struct PlayerVolumeSlider: View {
    let model: AppModel
    let width: CGFloat

    init(model: AppModel, width: CGFloat = 96) {
        self.model = model
        self.width = width
    }

    var body: some View {
        Slider(
            value: Binding(
                get: { Double(model.volume) },
                set: { model.volume = Float($0) }
            ),
            in: 0 ... 1
        )
        .controlSize(.small)
        .tint(.black)
        .frame(width: width)
        .accessibilityLabel("Volume")
        .accessibilityIdentifier("player.volume")
    }
}
