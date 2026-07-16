import SwiftUI

struct StationRow: View {
    let station: Station
    let model: AppModel
    let artwork: ArtworkLoader

    var body: some View {
        HStack(spacing: 11) {
            StationArtworkView(station: station, loader: artwork)
            VStack(alignment: .leading, spacing: 2) {
                Text(station.name).fontWeight(.semibold).lineLimit(1)
                Text([station.country, station.tags.first].compactMap { $0 }.joined(separator: " · ")).foregroundStyle(.secondary).lineLimit(1)
                Text(quality).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.toggleFavorite(station) } label: { Image(systemName: model.isFavorite(station) ? "star.fill" : "star") }
                .buttonStyle(.plain).foregroundStyle(model.isFavorite(station) ? .yellow : .secondary).help("Favorite")
        }.contentShape(.rect).onTapGesture { model.select(station) }.accessibilityElement(children: .combine)
    }

    private var quality: String { [station.primarySource?.bitrate.map { "\($0) kbps" }, station.primarySource?.codec].compactMap { $0 }.joined(separator: " · ") }
}
