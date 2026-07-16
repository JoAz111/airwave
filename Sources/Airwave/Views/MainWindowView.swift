import SwiftUI

struct MainWindowView: View {
    @Bindable var model: AppModel
    let artwork: ArtworkLoader
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                TextField(
                    model.searchPlaceholder,
                    text: Binding(get: { model.query }, set: model.updateQuery)
                ).textFieldStyle(.roundedBorder)
                Picker(
                    "Library",
                    selection: Binding(
                        get: { model.libraryMode },
                        set: { mode in Task { await model.activate(mode) } }
                    )
                ) {
                    ForEach(LibraryMode.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
            }.padding()
            Group {
                if model.isLoading && model.visibleStations.isEmpty { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if let error = model.errorMessage, model.visibleStations.isEmpty { ContentUnavailableView("Stations unavailable", systemImage: "wifi.exclamationmark", description: Text(error)).overlay(alignment: .bottom) { Button("Retry") { model.retry() }.padding() } }
                else { List(model.visibleStations) { StationRow(station: $0, model: model, artwork: artwork) }.listStyle(.plain) }
            }
            NowPlayingBar(model: model, artwork: artwork)
        }.frame(minWidth: 340, minHeight: 440).task { await model.start() }
    }
}
