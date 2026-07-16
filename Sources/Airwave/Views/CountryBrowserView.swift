import SwiftUI

struct CountryBrowserView: View {
    let model: AppModel
    let artwork: ArtworkLoader

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
        List {
            ForEach(
                Array(model.visibleCountries.enumerated()),
                id: \.element.id
            ) { index, country in
                if index == 1, model.visibleCountries.first?.isLocal == true {
                    Divider()
                }
                Button {
                    Task { await model.selectCountry(country) }
                } label: {
                    HStack(spacing: 12) {
                        Text(country.flag)
                            .font(.title2)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(country.name)
                                .fontWeight(country.isLocal ? .semibold : .regular)
                            if country.isLocal {
                                Text("Mac Region")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if country.stationCount > 0 {
                            Text(country.stationCount.formatted())
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(country.name)
                .accessibilityValue(country.isLocal ? "Mac Region" : "")
            }
        }
        .airwaveBrowserList()
        .overlay {
            if model.visibleCountries.isEmpty {
                ContentUnavailableView.search(text: model.query)
            }
        }
        .accessibilityLabel("Countries")
    }

    private func selectedCountryList(_ country: Country) -> some View {
        List {
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
