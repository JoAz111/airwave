import SwiftUI

struct CountryBrowserView: View {
    let model: AppModel
    let artwork: ArtworkLoader
    private let columns = [
        GridItem(.adaptive(minimum: 118, maximum: 154), spacing: 12)
    ]

    var body: some View {
        if let selectedCountry = model.selectedCountry {
            selectedCountryList(selectedCountry)
        } else if model.isLoading && model.visibleCountries.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Loading countries")
        } else {
            countryList
        }
    }

    private var countryList: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(model.visibleCountries) { country in
                    CountryCard(country: country) {
                        Task { await model.selectCountry(country) }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 126)
            .padding(.bottom, 104)
        }
        .scrollIndicators(.automatic)
        .overlay {
            if model.visibleCountries.isEmpty {
                ContentUnavailableView.search(text: model.query)
            }
        }
        .accessibilityLabel("Countries")
    }

    private func selectedCountryList(_ country: Country) -> some View {
        List {
            FloatingHeaderSpacer()
            Button { model.backToCountries() } label: {
                Label("Countries", systemImage: "chevron.left")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.plain)

            if model.isLoading && model.visibleStations.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if let error = model.errorMessage, model.visibleStations.isEmpty {
                VStack(spacing: 10) {
                    Label(error, systemImage: "wifi.exclamationmark")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { model.retry() }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .listRowSeparator(.hidden)
            } else if model.visibleStations.isEmpty {
                ContentUnavailableView(
                    "No stations in \(country.name)",
                    systemImage: "radio",
                    description: Text("Try another country.")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(model.visibleStations) { station in
                    StationRow(station: station, model: model, artwork: artwork)
                }
            }
        }
        .airwaveBrowserList()
        .accessibilityLabel("Stations in \(country.name)")
    }
}

extension View {
    func airwaveBrowserList() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 92, for: .scrollContent)
    }
}
