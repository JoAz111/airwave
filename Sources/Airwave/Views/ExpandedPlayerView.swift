import SwiftUI

struct ExpandedPlayerView: View {
    let station: Station
    let model: AppModel
    let artwork: ArtworkLoader
    let onDismiss: () -> Void

    @State private var backgroundImage: NSImage?

    var body: some View {
        ZStack {
            backdrop

            playerContent
                .frame(maxWidth: 500)
                .padding(.horizontal, 56)
                .padding(.vertical, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            closeButton.padding(22)
        }
        .overlay(alignment: .topTrailing) {
            volumeControl.padding(22)
        }
        .foregroundStyle(.black)
        .tint(.black)
        .task(id: station.id) {
            backgroundImage = await artwork.image(for: station)
        }
        .onExitCommand(perform: onDismiss)
        .accessibilityLabel("Expanded player")
    }

    private var backdrop: some View {
        ZStack {
            if let backgroundImage {
                Image(nsImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.18)
                    .blur(radius: 54)
            } else {
                Color(nsColor: .underPageBackgroundColor)
            }

            Color.white.opacity(0.50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var playerContent: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 44)

            StationArtworkView(station: station, loader: artwork, size: 240)
                .shadow(color: .black.opacity(0.20), radius: 24, y: 12)

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(primaryTitle)
                        .font(.title2.bold())
                        .lineLimit(1)
                    Text(secondaryTitle)
                        .font(.title3)
                        .foregroundStyle(.black.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Button { model.toggleFavorite(station) } label: {
                    Image(systemName: model.isFavorite(station) ? "star.fill" : "star")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .tint(.black)
                .help("Favorite")
            }

            HStack(spacing: 12) {
                Capsule().fill(.black.opacity(0.16)).frame(height: 5)
                Text("LIVE").font(.caption.bold())
                Capsule().fill(.black.opacity(0.16)).frame(height: 5)
            }

            playButton
            Spacer(minLength: 4)
        }
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(.black)
        .help("Close player")
        .keyboardShortcut(.cancelAction)
    }

    private var volumeControl: some View {
        HStack(spacing: 9) {
            Image(systemName: "speaker.fill").font(.caption)
            PlayerVolumeSlider(model: model)
            Image(systemName: "speaker.wave.3.fill").font(.caption)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .glassEffect(
            .regular.tint(.white.opacity(0.24)).interactive(),
            in: .capsule
        )
    }

    private var playButton: some View {
        Button { model.togglePlayback() } label: {
            ZStack {
                Image(systemName: model.playbackState == .playing ? "pause.fill" : "play.fill")
                    .opacity(isBuffering ? 0 : 1)
                if isBuffering {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
            }
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(.black)
        .help(model.playbackState == .playing ? "Pause" : "Play")
    }

    private var primaryTitle: String {
        model.metadata?.title ?? station.name
    }

    private var secondaryTitle: String {
        if let artist = model.metadata?.artist { return artist }
        return [station.name, station.country].compactMap { $0 }.joined(separator: " · ")
    }

    private var isBuffering: Bool {
        model.playbackState == .loading || model.playbackState == .waiting
    }
}
