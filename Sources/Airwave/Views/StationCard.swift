import SwiftUI

struct StationCard: View {
    let station: Station
    let model: AppModel
    let artwork: ArtworkLoader

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button { model.select(station) } label: {
                cardContent
            }
            .buttonStyle(.plain)
            .accessibilityValue(isActive ? "Playing" : "")

            favoriteButton
        }
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.16), value: isHovering)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            StationArtworkView(station: station, loader: artwork, size: nil)
                .overlay {
                    if isHovering || isActive {
                        Circle()
                            .fill(.black.opacity(0.56))
                            .frame(width: 42, height: 42)
                            .overlay {
                                Image(systemName: isActive ? "waveform" : "play.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: isActive ? 0 : 1)
                            }
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(isHovering ? 1.012 : 1)

            Text(station.name)
                .font(.headline)
                .lineLimit(1)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(.rect(cornerRadius: 14))
    }

    private var favoriteButton: some View {
        Button { model.toggleFavorite(station) } label: {
            Image(systemName: model.isFavorite(station) ? "star.fill" : "star")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(model.isFavorite(station) ? .yellow : .white)
                .frame(width: 28, height: 28)
                .background(.black.opacity(0.48), in: .circle)
        }
        .buttonStyle(.plain)
        .padding(8)
        .opacity(isHovering || model.isFavorite(station) ? 1 : 0)
        .help(model.isFavorite(station) ? "Remove favorite" : "Favorite")
        .accessibilityLabel(model.isFavorite(station) ? "Remove favorite" : "Favorite")
    }

    private var isActive: Bool {
        model.currentStation?.id == station.id
    }

    private var detail: String {
        let bitrate = station.primarySource?.bitrate.map { "\($0) kbps" }
        return [station.country, bitrate].compactMap { $0 }.joined(separator: " · ")
    }
}
