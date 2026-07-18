import Foundation

/// The raw country count returned by the radio directory.
struct CountryDirectoryEntry: Equatable, Sendable {
    let code: String
    let stationCount: Int
}

/// A localized country presented in the country browser.
struct Country: Equatable, Identifiable, Sendable {
    let code: String
    let name: String
    let stationCount: Int
    let isLocal: Bool

    var id: String { code }

    /// Returns the Unicode regional-indicator flag used only as an accessibility fallback.
    var flag: String {
        code.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(127_397 + $0.value) }
            .map(String.init)
            .joined()
    }
}

enum CountryCatalog {
    /// Localizes, validates, sorts, and locale-pins directory country entries.
    static func make(
        entries: [CountryDirectoryEntry],
        locale: Locale,
        localCode: String?
    ) -> [Country] {
        let normalizedLocal = normalizedCode(localCode)
        let unique = Dictionary(
            entries.compactMap { entry -> (String, CountryDirectoryEntry)? in
                guard let code = normalizedCode(entry.code) else { return nil }
                return (
                    code,
                    CountryDirectoryEntry(
                        code: code,
                        stationCount: max(0, entry.stationCount)
                    )
                )
            },
            uniquingKeysWith: { lhs, rhs in
                CountryDirectoryEntry(
                    code: lhs.code,
                    stationCount: max(lhs.stationCount, rhs.stationCount)
                )
            }
        )

        let countries = unique.values.compactMap { entry -> Country? in
            guard let name = locale.localizedString(forRegionCode: entry.code) else {
                return nil
            }
            return Country(
                code: entry.code,
                name: name,
                stationCount: entry.stationCount,
                isLocal: entry.code == normalizedLocal
            )
        }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        guard let localIndex = countries.firstIndex(where: \.isLocal) else {
            return countries
        }
        var result = countries
        result.insert(result.remove(at: localIndex), at: 0)
        return result
    }

    /// Supplies Foundation regions if the remote directory is temporarily unavailable.
    static func fallback(locale: Locale, localCode: String?) -> [Country] {
        make(
            entries: Locale.Region.isoRegions
                .map(\.identifier)
                .filter { normalizedCode($0) != nil }
                .map { CountryDirectoryEntry(code: $0, stationCount: 0) },
            locale: locale,
            localCode: localCode
        )
    }

    /// Filters localized country names and ISO codes without a remote request.
    static func filter(_ countries: [Country], query: String) -> [Country] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return countries }
        return countries.filter {
            $0.code.localizedCaseInsensitiveContains(value)
                || $0.name.localizedCaseInsensitiveContains(value)
        }
    }

    private static func normalizedCode(_ value: String?) -> String? {
        guard let value else { return nil }
        let code = value.uppercased()
        guard code.utf8.count == 2,
              code.utf8.allSatisfy({ (65 ... 90).contains($0) }) else {
            return nil
        }
        return code
    }
}
