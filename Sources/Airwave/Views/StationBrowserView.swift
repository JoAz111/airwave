import SwiftUI

struct StationBrowserView: View {
    let model: AppModel
    let artwork: ArtworkLoader

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader
                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, model.currentStation == nil ? 28 : 112)
        }
        .scrollIndicators(.automatic)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.largeTitle.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.visibleStations.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 340)
        } else if let error = model.errorMessage, model.visibleStations.isEmpty {
            ContentUnavailableView(
                "Stations unavailable",
                systemImage: "wifi.exclamationmark",
                description: Text(error)
            )
            .frame(maxWidth: .infinity, minHeight: 340)
            Button("Retry") { model.retry() }
                .frame(maxWidth: .infinity)
        } else if model.visibleStations.isEmpty {
            ContentUnavailableView.search(text: model.query)
                .frame(maxWidth: .infinity, minHeight: 340)
        } else if showsExploreSections {
            StationSection(title: "Near You") {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 18) {
                        ForEach(featuredStations) { station in
                            StationCard(station: station, model: model, artwork: artwork)
                                .frame(width: 166)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if !remainingStations.isEmpty {
                StationSection(title: "More to Explore") {
                    StationGrid(
                        stations: remainingStations,
                        model: model,
                        artwork: artwork
                    )
                }
            }
        } else {
            StationGrid(stations: model.visibleStations, model: model, artwork: artwork)
        }
    }

    private var showsExploreSections: Bool {
        model.libraryMode == .explore
            && model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && model.visibleStations.count > 6
    }

    private var featuredStations: [Station] {
        Array(model.visibleStations.prefix(6))
    }

    private var remainingStations: [Station] {
        Array(model.visibleStations.dropFirst(6))
    }

    private var title: String {
        switch model.libraryMode {
        case .explore where !model.query.isEmpty: "Search Results"
        case .explore: "Explore"
        case .favorites: "Favorites"
        case .recent: "Recently Played"
        case .countries: "Stations"
        }
    }

    private var subtitle: String {
        switch model.libraryMode {
        case .explore: "Live radio selected for you"
        case .favorites: "The stations you want close by"
        case .recent: "Pick up where you left off"
        case .countries: "Live stations from around the world"
        }
    }
}

struct StationGrid: View {
    let stations: [Station]
    let model: AppModel
    let artwork: ArtworkLoader

    private let columns = [
        GridItem(.adaptive(minimum: 142, maximum: 190), spacing: 18)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
            ForEach(stations) { station in
                StationCard(station: station, model: model, artwork: artwork)
            }
        }
    }
}

private struct StationSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
            content
        }
    }
}
