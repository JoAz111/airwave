import SwiftUI

struct NowPlayingBar: View {
    let model: AppModel
    let artwork: ArtworkLoader
    var body: some View {
        HStack(spacing: 10) {
            if let station = model.currentStation { StationArtworkView(station: station, loader: artwork, size: 42) }
            VStack(alignment: .leading, spacing: 1) {
                Text(model.currentStation?.name ?? "Choose a station").fontWeight(.semibold).lineLimit(1)
                Text(model.metadata?.displayText ?? stateText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button { model.togglePlayback() } label: { Image(systemName: model.playbackState == .playing ? "pause.fill" : "play.fill") }
                .buttonStyle(.glassProminent).disabled(model.currentStation == nil).help("Play or pause")
            Slider(value: Binding(get: { Double(model.volume) }, set: { model.volume = Float($0) }), in: 0 ... 1).frame(width: 78).accessibilityLabel("Volume")
        }.padding(10).glassEffect(.regular, in: .rect(cornerRadius: 15)).padding([.horizontal, .bottom], 10)
    }
    private var stateText: String { switch model.playbackState { case .loading, .waiting: "Buffering…"; case .playing: "Playing live"; case .failed(let text): text; default: "Live broadcast" } }
}
