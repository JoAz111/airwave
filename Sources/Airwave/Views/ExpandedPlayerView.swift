import SwiftUI

struct ExpandedPlayerView: View {
    let station: Station
    let model: AppModel
    let artwork: ArtworkLoader
    let transitionNamespace: Namespace.ID
    let onDismiss: () -> Void

    @State private var backgroundImage: NSImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backdrop

                VStack(spacing: 0) {
                    topControls
                    Spacer(minLength: 12)

                    StationArtworkView(
                        station: station,
                        loader: artwork,
                        size: artworkSize(for: geometry.size)
                    )
                    .matchedGeometryEffect(
                        id: "now-playing-artwork",
                        in: transitionNamespace
                    )
                    .shadow(color: .black.opacity(0.22), radius: 28, y: 14)

                    playerDetails
                        .frame(maxWidth: 500)
                        .padding(.top, 24)

                    Spacer(minLength: 16)
                }
                .padding(24)
            }
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
                    .scaleEffect(1.22)
                    .blur(radius: 58)
            } else {
                Color(nsColor: .underPageBackgroundColor)
            }

            Color.white.opacity(0.48)
        }
        .ignoresSafeArea()
        .clipped()
    }

    private var topControls: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(.black)
            .help("Close player")
            .keyboardShortcut(.cancelAction)

            Spacer()

            HStack(spacing: 9) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                PlayerVolumeSlider(model: model)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }

    private var playerDetails: some View {
        VStack(spacing: 18) {
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
                Text("LIVE")
                    .font(.caption.bold())
                Capsule().fill(.black.opacity(0.16)).frame(height: 5)
            }

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
    }

    private func artworkSize(for size: CGSize) -> CGFloat {
        min(300, max(210, size.height * 0.42), size.width * 0.54)
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
