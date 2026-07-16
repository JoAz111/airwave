import AppKit
import SwiftUI

struct MenuBarPlayerView: View {
    @Environment(\.openWindow) private var openWindow
    let model: AppModel
    let artwork: ArtworkLoader
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let station = model.currentStation {
                HStack { StationArtworkView(station: station, loader: artwork, size: 52); VStack(alignment: .leading) { Text(station.name).fontWeight(.semibold); Text(model.metadata?.displayText ?? "Live broadcast").foregroundStyle(.secondary).lineLimit(2) } }
            } else { Label("Choose a station", systemImage: "antenna.radiowaves.left.and.right") }
            HStack { Button { model.togglePlayback() } label: { Image(systemName: model.playbackState == .playing ? "pause.fill" : "play.fill") }; Slider(value: Binding(get: { Double(model.volume) }, set: { model.volume = Float($0) }), in: 0 ... 1) }
            Divider()
            Button("Open Airwave") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }.keyboardShortcut("o")
            Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }.padding(14).frame(width: 290)
    }
}
