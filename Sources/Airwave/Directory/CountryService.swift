import Foundation

/// Provides the country browser with localized, directory-backed country entries.
protocol CountryLoading: Sendable {
    /// Loads countries and orders the user's locale first when possible.
    func load(locale: Locale, localCode: String?) async -> [Country]
}

/// Adapts Radio Browser country counts into the app's localized country model.
actor CountryService: CountryLoading {
    private let directory: any RadioBrowserServing

    /// Creates a country loader using the shared radio directory.
    init(directory: any RadioBrowserServing) {
        self.directory = directory
    }

    /// Returns directory counts, falling back to Foundation's region catalog offline.
    func load(locale: Locale, localCode: String?) async -> [Country] {
        do {
            return CountryCatalog.make(
                entries: try await directory.countryCodes(),
                locale: locale,
                localCode: localCode
            )
        } catch {
            return CountryCatalog.fallback(locale: locale, localCode: localCode)
        }
    }
}
