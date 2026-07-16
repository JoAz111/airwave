import Foundation

protocol CountryLoading: Sendable {
    func load(locale: Locale, localCode: String?) async -> [Country]
}

actor CountryService: CountryLoading {
    private let directory: any RadioBrowserServing

    init(directory: any RadioBrowserServing) {
        self.directory = directory
    }

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
