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

            GeometryReader { proxy in
                let layout = ExpandedPlayerLayout(availableSize: proxy.size)

                playerContent(layout: layout)
                    .frame(width: layout.contentWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, layout.titlebarClearance)
                    .padding(.horizontal, layout.horizontalInset)
                    .padding(.bottom, layout.bottomInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            closeButton
                .padding(.leading, 20)
                .padding(.top, 52)
        }
        .overlay(alignment: .topTrailing) {
            volumeControl
                .padding(.trailing, 20)
                .padding(.top, 52)
        }
        .foregroundStyle(.black)
        .tint(.black)
        .task(id: station.id) {
            backgroundImage = await artwork.image(for: station)
        }
        .onDisappear { backgroundImage = nil }
        .onExitCommand(perform: onDismiss)
        .accessibilityLabel("Expanded player")
    }

    private var backdrop: some View {
        ZStack {
            Color.white

            if let backgroundImage {
                Image(nsImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.18)
                    .blur(radius: 72)
                    .opacity(0.16)
            }

            Color.white.opacity(0.28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func playerContent(layout: ExpandedPlayerLayout) -> some View {
        VStack(spacing: layout.contentSpacing) {
            Spacer(minLength: 0)

            StationArtworkView(station: station, loader: artwork, size: layout.artworkSize)
                .shadow(color: .black.opacity(0.14), radius: 20, y: 10)

            HStack(spacing: 12) {
                Color.clear.frame(width: 36, height: 36)
                VStack(alignment: .center, spacing: 3) {
                    Text(primaryTitle)
                        .font(.title2.bold())
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(secondaryTitle)
                        .font(.title3)
                        .foregroundStyle(.black.opacity(0.62))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .layoutPriority(-1)
                Button { model.toggleFavorite(station) } label: {
                    Image(systemName: model.isFavorite(station) ? "star.fill" : "star")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .tint(.black)
                .frame(width: 36, height: 36)
                .help("Favorite")
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Capsule().fill(.black.opacity(0.16)).frame(height: 5)
                Text("LIVE").font(.caption.bold())
                Capsule().fill(.black.opacity(0.16)).frame(height: 5)
            }
            .frame(maxWidth: .infinity)

            PlayerPrimaryButton(
                isPlaybackActive: model.isPlaybackActive,
                isBuffering: isBuffering,
                diameter: PlayerPrimaryButton.expandedDiameter,
                action: model.togglePlayback
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Image(systemName: "speaker.fill").font(.body.weight(.medium))
            PlayerVolumeSlider(model: model, width: 120)
            Image(systemName: "speaker.wave.3.fill").font(.body.weight(.medium))
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .glassEffect(
            .regular.tint(.white.opacity(0.24)).interactive(),
            in: .capsule
        )
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

struct ExpandedPlayerLayout {
    let availableSize: CGSize

    private var isCompactHeight: Bool { availableSize.height < 590 }

    var horizontalInset: CGFloat {
        min(56, max(20, availableSize.width * 0.06))
    }

    var contentWidth: CGFloat {
        min(500, max(0, availableSize.width - horizontalInset * 2))
    }

    var artworkSize: CGFloat {
        let widthLimit = contentWidth * 0.62
        let heightLimit = max(140, availableSize.height - 300)
        return min(248, max(140, min(widthLimit, heightLimit)))
    }

    var contentSpacing: CGFloat { isCompactHeight ? 14 : 20 }
    var titlebarClearance: CGFloat { isCompactHeight ? 66 : 78 }
    var bottomInset: CGFloat { isCompactHeight ? 16 : 28 }
}
