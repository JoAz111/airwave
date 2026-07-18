import SwiftUI

struct PlayerPrimaryButton: View {
    static let compactDiameter: CGFloat = 40
    static let expandedDiameter: CGFloat = 56

    let isPlaybackActive: Bool
    let isBuffering: Bool
    let diameter: CGFloat
    let action: () -> Void

    static func actionLabel(isPlaybackActive: Bool) -> String {
        isPlaybackActive ? "Stop" : "Play live"
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: isPlaybackActive ? "stop.fill" : "play.fill")
                    .opacity(isBuffering ? 0 : 1)
                if isBuffering {
                    ProgressView().controlSize(.small).tint(.white)
                }
            }
            .font(.system(size: diameter >= 52 ? 22 : 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(.black)
        .help(Self.actionLabel(isPlaybackActive: isPlaybackActive))
        .accessibilityLabel(Self.actionLabel(isPlaybackActive: isPlaybackActive))
    }
}
