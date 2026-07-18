import SwiftUI

struct MainWindowView: View {
    let model: AppModel
    let artwork: ArtworkLoader
    @State private var isPlayerExpanded = false

    var body: some View {
        ZStack {
            browser
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isPlayerExpanded, let station = model.currentStation {
                ExpandedPlayerView(
                    station: station,
                    model: model,
                    artwork: artwork
                ) {
                    withAnimation(.smooth(duration: 0.38)) {
                        isPlayerExpanded = false
                    }
                }
                .transition(.scale(scale: 0.985).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .overlay(alignment: .bottom) {
            if model.currentStation != nil && !isPlayerExpanded {
                NowPlayingBar(
                    model: model,
                    artwork: artwork
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
        .background(isPlayerExpanded ? Color.clear : Color.white)
        .containerBackground(isPlayerExpanded ? Color.clear : Color.white, for: .window)
        .toolbar {
            if !isPlayerExpanded {
                ToolbarItem(placement: .principal) {
                    LibraryTabBar(model: model)
                }
            }
        }
        .modifier(
            AirwaveSearchModifier(
                isEnabled: !isPlayerExpanded,
                text: Binding(get: { model.query }, set: model.updateQuery),
                prompt: model.searchPlaceholder
            )
        )
        .tint(AirwaveStyle.accent)
        .preferredColorScheme(.light)
        .animation(.snappy(duration: 0.24), value: model.libraryMode)
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

private struct AirwaveSearchModifier: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String
    let prompt: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .searchable(
                    text: $text,
                    placement: .toolbar,
                    prompt: Text(prompt)
                )
                .searchToolbarBehavior(.automatic)
        } else {
            content
        }
    }
}
