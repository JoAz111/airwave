import SwiftUI

struct StationArtworkView: View {
    let station: Station
    let loader: ArtworkLoader
    var size: CGFloat = 44
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else { Image(systemName: "antenna.radiowaves.left.and.right").font(.title3).foregroundStyle(.secondary) }
        }
        .frame(width: size, height: size).background(.quaternary, in: .rect(cornerRadius: 9)).clipShape(.rect(cornerRadius: 9))
        .task(id: station.faviconURL) { image = await loader.image(for: station.faviconURL) }
    }
}
