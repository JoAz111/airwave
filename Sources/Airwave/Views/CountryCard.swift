import SwiftUI

struct CountryCard: View {
    let country: Country
    let artwork: ArtworkLoader
    let action: () -> Void

    @State private var flagImage: NSImage?
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                flagBackground
                LinearGradient(
                    colors: [.clear, .black.opacity(0.12), .black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(country.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text(stationCount)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }
                .padding(13)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.02 : 1)
        .shadow(
            color: .black.opacity(isHovering ? 0.18 : 0.09),
            radius: isHovering ? 10 : 5,
            y: isHovering ? 5 : 2
        )
        .animation(.spring(duration: 0.22, bounce: 0.14), value: isHovering)
        .onHover { isHovering = $0 }
        .task(id: country.code) {
            flagImage = await artwork.image(for: flagURL)
        }
        .accessibilityLabel(country.name)
        .accessibilityValue(stationCount)
    }

    @ViewBuilder
    private var flagBackground: some View {
        if let flagImage {
            Image(nsImage: flagImage)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    ProgressView()
                        .controlSize(.small)
                }
        }
    }

    private var flagURL: URL? {
        URL(string: "https://flagcdn.com/w320/\(country.code.lowercased()).png")
    }

    private var stationCount: String {
        guard country.stationCount > 0 else { return "Radio directory" }
        return "\(country.stationCount.formatted()) stations"
    }
}
