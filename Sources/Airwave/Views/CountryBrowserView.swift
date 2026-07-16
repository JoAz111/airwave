import SwiftUI

struct CountryBrowserView: View {
    let model: AppModel
    let artwork: ArtworkLoader

    private let columns = [
        GridItem(.adaptive(minimum: 142, maximum: 190), spacing: 18)
    ]

    var body: some View {
        if let selectedCountry = model.selectedCountry {
            selectedCountryView(selectedCountry)
        } else {
            countryGrid
        }
    }

    private var countryGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                pageHeader(title: "Countries", subtitle: "Tune in around the world")

                if model.isLoading && model.visibleCountries.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 340)
                        .accessibilityLabel("Loading countries")
                } else if model.visibleCountries.isEmpty {
                    ContentUnavailableView.search(text: model.query)
                        .frame(maxWidth: .infinity, minHeight: 340)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                        ForEach(model.visibleCountries) { country in
                            CountryCard(country: country, artwork: artwork) {
                                Task { await model.selectCountry(country) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, model.currentStation == nil ? 28 : 112)
        }
        .scrollIndicators(.automatic)
        .accessibilityLabel("Countries")
    }

    private func selectedCountryView(_ country: Country) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Button { model.backToCountries() } label: {
                    Label("Countries", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .fontWeight(.semibold)

                pageHeader(
                    title: country.name,
                    subtitle: "\(country.stationCount.formatted()) live stations"
                )

                if model.isLoading && model.visibleStations.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 320)
                } else if let error = model.errorMessage, model.visibleStations.isEmpty {
                    ContentUnavailableView(
                        "Stations unavailable",
                        systemImage: "wifi.exclamationmark",
                        description: Text(error)
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                    Button("Retry") { model.retry() }
                        .frame(maxWidth: .infinity)
                } else if model.visibleStations.isEmpty {
                    ContentUnavailableView(
                        "No stations in \(country.name)",
                        systemImage: "radio",
                        description: Text("Try another country.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    StationGrid(
                        stations: model.visibleStations,
                        model: model,
                        artwork: artwork
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, model.currentStation == nil ? 28 : 112)
        }
        .scrollIndicators(.automatic)
        .accessibilityLabel("Stations in \(country.name)")
    }

    private func pageHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.largeTitle.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
