import SwiftUI

struct StationArtworkView: View {
    let station: Station
    let loader: ArtworkLoader
    var size: CGFloat? = 44
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let size {
                artwork
                    .frame(width: size, height: size)
            } else {
                artwork
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(.quaternary)
        .clipShape(.rect(cornerRadius: size == nil ? 14 : 9))
        .task(id: station.id) { image = await loader.image(for: station) }
    }

    @ViewBuilder
    private var artwork: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(artworkPadding)
        } else {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(size == nil ? .system(size: 34) : .title3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var artworkPadding: CGFloat {
        guard let size else { return 12 }
        return size >= 100 ? 16 : 3
    }
}
