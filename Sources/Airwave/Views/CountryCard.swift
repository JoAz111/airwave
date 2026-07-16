import SwiftUI

struct CountryCard: View {
    let country: Country
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(country.flag)
                        .font(.system(size: 34))
                        .accessibilityHidden(true)
                    Spacer(minLength: 6)
                    if country.isLocal {
                        Image(systemName: "location.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)
                            .padding(7)
                            .background(.ultraThinMaterial, in: .circle)
                            .help("Your Mac region")
                    }
                }

                Spacer(minLength: 8)

                Text(country.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 5) {
                    Text(stationCount)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .accessibilityHidden(true)
                }
                .padding(.top, 5)
            }
            .padding(13)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(cardBackground)
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.025 : 1)
        .shadow(
            color: .black.opacity(isHovering ? 0.14 : 0.07),
            radius: isHovering ? 10 : 4,
            y: isHovering ? 5 : 2
        )
        .animation(.spring(duration: 0.22, bounce: 0.16), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityLabel(country.name)
        .accessibilityValue(accessibilityValue)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(colorScheme == .dark ? 0.34 : 0.22),
                                accent.opacity(colorScheme == .dark ? 0.08 : 0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isHovering ? accent.opacity(0.52) : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            }
    }

    private var accent: Color {
        let value = country.code.unicodeScalars.reduce(0) { partial, scalar in
            partial + Int(scalar.value)
        }
        return Color(
            hue: Double((value * 47) % 360) / 360,
            saturation: colorScheme == .dark ? 0.62 : 0.72,
            brightness: colorScheme == .dark ? 0.92 : 0.78
        )
    }

    private var stationCount: String {
        guard country.stationCount > 0 else { return "Radio directory" }
        return "\(country.stationCount.formatted()) stations"
    }

    private var accessibilityValue: String {
        [country.isLocal ? "Your Mac region" : nil, stationCount]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
