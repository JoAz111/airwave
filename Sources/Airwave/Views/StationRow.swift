import SwiftUI

struct StationRow: View {
    let station: Station
    let model: AppModel
    let artwork: ArtworkLoader
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 11) {
            StationArtworkView(station: station, loader: artwork)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isActive {
                        Circle()
                            .fill(AirwaveStyle.signalGradient)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                    }
                    Text(station.name).fontWeight(.semibold).lineLimit(1)
                }
                Text([station.country, station.tags.first].compactMap { $0 }.joined(separator: " · ")).foregroundStyle(.secondary).lineLimit(1)
                Text(quality).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.toggleFavorite(station) } label: { Image(systemName: model.isFavorite(station) ? "star.fill" : "star") }
                .buttonStyle(.plain)
                .foregroundStyle(model.isFavorite(station) ? .yellow : .secondary)
                .opacity(isHovering || model.isFavorite(station) ? 1 : 0.55)
                .help("Favorite")
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
        .onTapGesture { model.select(station) }
        .onHover { isHovering = $0 }
        .listRowBackground(isActive ? AirwaveStyle.accent.opacity(0.08) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isActive ? "Playing" : "")
    }

    private var isActive: Bool { model.currentStation?.id == station.id }
    private var quality: String { [station.primarySource?.bitrate.map { "\($0) kbps" }, station.primarySource?.codec].compactMap { $0 }.joined(separator: " · ") }
}
