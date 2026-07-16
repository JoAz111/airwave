import SwiftUI

struct CountryCard: View {
    let country: Country
    let artwork: ArtworkLoader
    let action: () -> Void

    @State private var flagImage: NSImage?
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            CountryFlagCardContent(country: country, flagImage: flagImage)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.012 : 1)
        .animation(.smooth(duration: 0.18), value: isHovering)
        .onHover { isHovering = $0 }
        .task(id: country.code) {
            flagImage = await artwork.image(
                for: flagURL,
                maxPixelSize: ArtworkPixelBudget.countryFlag
            )
        }
        .onDisappear { flagImage = nil }
        .accessibilityLabel(country.name)
        .accessibilityValue(
            country.stationCount > 0
                ? "\(country.stationCount.formatted()) stations"
                : "Radio directory"
        )
    }

    private var flagURL: URL? {
        URL(string: "https://flagcdn.com/w320/\(country.code.lowercased()).png")
    }
}

struct CountryFlagCardContent: View {
    let country: Country
    let flagImage: NSImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                flagBackground
                    .frame(width: geometry.size.width, height: geometry.size.height)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.08), .black.opacity(0.76)],
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
                .padding(12)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: 14))
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

    private var stationCount: String {
        guard country.stationCount > 0 else { return "Radio directory" }
        return "\(country.stationCount.formatted()) stations"
    }
}
