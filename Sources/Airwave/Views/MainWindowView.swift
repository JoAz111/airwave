import SwiftUI

struct MainWindowView: View {
    let model: AppModel
    let artwork: ArtworkLoader

    var body: some View {
        ZStack(alignment: .top) {
            browser
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            floatingHeader
        }
        .overlay(alignment: .bottom) {
            NowPlayingBar(model: model, artwork: artwork)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(minWidth: 360, minHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .containerBackground(Color(nsColor: .windowBackgroundColor), for: .window)
        .tint(AirwaveStyle.accent)
        .task { await model.start() }
    }

    private var floatingHeader: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                FloatingSearchField(
                    placeholder: model.searchPlaceholder,
                    text: Binding(get: { model.query }, set: model.updateQuery)
                )
                LibraryTabBar(model: model)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var browser: some View {
        if model.libraryMode == .countries {
            CountryBrowserView(model: model, artwork: artwork)
        } else if model.isLoading && model.visibleStations.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 84)
        } else if let error = model.errorMessage, model.visibleStations.isEmpty {
            ContentUnavailableView(
                "Stations unavailable",
                systemImage: "wifi.exclamationmark",
                description: Text(error)
            )
            .overlay(alignment: .bottom) {
                Button("Retry") { model.retry() }.padding()
            }
            .padding(.bottom, 84)
        } else {
            List {
                FloatingHeaderSpacer()
                ForEach(model.visibleStations) { station in
                    StationRow(station: station, model: model, artwork: artwork)
                }
            }
            .airwaveBrowserList()
        }
    }
}
