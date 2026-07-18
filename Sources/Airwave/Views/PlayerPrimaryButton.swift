import AppKit
import SwiftUI

struct PlayerPrimaryButton: View {
    let isPlaybackActive: Bool
    let isBuffering: Bool
    let diameter: CGFloat
    let action: () -> Void

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
        .help(isPlaybackActive ? "Stop" : "Play live")
        .accessibilityLabel(isPlaybackActive ? "Stop" : "Play live")
        .background {
            PlayerPrimaryButtonAccessibilityBridge(
                label: isPlaybackActive ? "Stop" : "Play live",
                diameter: diameter,
                action: action
            )
        }
    }
}

private struct PlayerPrimaryButtonAccessibilityBridge: NSViewRepresentable {
    let label: String
    let diameter: CGFloat
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.isTransparent = true
        button.focusRingType = .none
        button.target = context.coordinator
        button.action = #selector(Coordinator.performAction)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        button.setAccessibilityLabel(label)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NSButton,
        context: Context
    ) -> CGSize? {
        CGSize(width: diameter, height: diameter)
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) { self.action = action }

        @objc func performAction() { action() }
    }
}
