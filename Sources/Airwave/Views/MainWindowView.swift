import SwiftUI

struct MainWindowView: View {
    let model: AppModel
    let artwork: ArtworkLoader

    var body: some View {
        browser
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if model.currentStation != nil {
                NowPlayingBar(model: model, artwork: artwork)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
            }
        }
        .frame(minWidth: 560, minHeight: 520)
        .background(.white)
        .containerBackground(.white, for: .window)
        .toolbar {
            ToolbarItem(placement: .principal) {
                LibraryTabBar(model: model)
            }
        }
        .searchable(
            text: Binding(get: { model.query }, set: model.updateQuery),
            placement: .toolbar,
            prompt: Text(model.searchPlaceholder)
        )
        .searchToolbarBehavior(.automatic)
        .tint(AirwaveStyle.accent)
        .preferredColorScheme(.light)
        .task { await model.start() }
    }

    @ViewBuilder
    private var browser: some View {
        if model.libraryMode == .countries {
            CountryBrowserView(model: model, artwork: artwork)
        } else {
            StationBrowserView(model: model, artwork: artwork)
        }
    }
}
