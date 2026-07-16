import SwiftUI

struct MainWindowView: View {
    let model: AppModel
    let artwork: ArtworkLoader
    @State private var isPlayerExpanded = false
    @Namespace private var playerTransition

    var body: some View {
        ZStack {
            browser
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isPlayerExpanded, let station = model.currentStation {
                ExpandedPlayerView(
                    station: station,
                    model: model,
                    artwork: artwork,
                    transitionNamespace: playerTransition
                ) {
                    withAnimation(.smooth(duration: 0.38)) {
                        isPlayerExpanded = false
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .overlay(alignment: .bottom) {
            if model.currentStation != nil && !isPlayerExpanded {
                NowPlayingBar(
                    model: model,
                    artwork: artwork,
                    transitionNamespace: playerTransition
                ) {
                    withAnimation(.smooth(duration: 0.38)) {
                        isPlayerExpanded = true
                    }
                }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
        .toolbarVisibility(isPlayerExpanded ? .hidden : .visible, for: .windowToolbar)
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
