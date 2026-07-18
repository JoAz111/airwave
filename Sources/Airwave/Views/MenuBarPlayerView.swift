import AppKit
import SwiftUI

struct MenuBarPlayerView: View {
    @Environment(\.openWindow) private var openWindow
    let model: AppModel
    let artwork: ArtworkLoader

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let station = model.currentStation {
                HStack(spacing: 10) {
                    StationArtworkView(station: station, loader: artwork, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.name).fontWeight(.semibold)
                        Text(model.metadata?.displayText ?? statusText)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            } else {
                Label("Choose a station", systemImage: "antenna.radiowaves.left.and.right")
            }

            HStack {
                Button { model.togglePlayback() } label: {
                    Image(systemName: model.isPlaybackActive ? "stop.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(model.currentStation == nil)
                .help(model.isPlaybackActive ? "Stop" : "Play live")
                Slider(value: Binding(get: { Double(model.volume) }, set: { model.volume = Float($0) }), in: 0 ... 1)
                    .tint(.black)
            }
            Divider()
            Button("Open Airwave") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("o")
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 290)
    }

    private var statusText: String {
        model.isPlaybackActive ? "Playing live" : "Stopped"
    }
}
