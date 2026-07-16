import Foundation
import OSLog

struct RadioBrowserQuery: Equatable, Sendable {
    enum Field: String, Sendable {
        case name
        case country
        case language
        case tag
    }

    let field: Field?
    let value: String
    let limit: Int
    let order: String
    let reverse: Bool
}

protocol RadioBrowserServing: Sendable {
    func stations(matching query: RadioBrowserQuery) async throws -> [Station]
    func recordClick(stationID: UUID) async
}

actor RadioBrowserClient: RadioBrowserServing {
    typealias Loader = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    private let mirrors: [URL]
    private let load: Loader
    private let logger = Logger(subsystem: "com.joeyazizoff.Airwave", category: "Directory")

    init(
        mirrors: [URL] = [
            URL(string: "https://de1.api.radio-browser.info")!,
            URL(string: "https://nl1.api.radio-browser.info")!,
            URL(string: "https://at1.api.radio-browser.info")!
        ],
        load: @escaping Loader = RadioBrowserClient.liveLoad
    ) {
        self.mirrors = mirrors
        self.load = load
    }

    func stations(matching query: RadioBrowserQuery) async throws -> [Station] {
        var lastError: Error?

        for mirror in mirrors.prefix(2) {
            do {
                let request = try makeRequest(mirror: mirror, query: query)
                let (data, response) = try await load(request)
                guard (200 ... 299).contains(response.statusCode) else {
                    throw DirectoryError.server(response.statusCode)
                }
                return try JSONDecoder().decode([Record].self, from: data).compactMap(\.station)
            } catch {
                lastError = error
                logger.notice("Directory mirror failed; trying fallback")
            }
        }

        throw lastError ?? DirectoryError.noMirrors
    }

    func recordClick(stationID: UUID) async {
        guard let mirror = mirrors.first else { return }
        var request = URLRequest(url: mirror.appending(path: "/json/url/\(stationID.uuidString)"))
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        _ = try? await load(request)
    }

    private func makeRequest(mirror: URL, query: RadioBrowserQuery) throws -> URLRequest {
        var components = URLComponents(
            url: mirror.appending(path: "/json/stations/search"),
            resolvingAgainstBaseURL: false
        )!
        var items = [
            URLQueryItem(name: "hidebroken", value: "true"),
            URLQueryItem(name: "limit", value: String(max(1, min(query.limit, 100)))),
            URLQueryItem(name: "order", value: query.order),
            URLQueryItem(name: "reverse", value: String(query.reverse))
        ]
        if let field = query.field, !query.value.isEmpty {
            items.append(URLQueryItem(name: field.rawValue, value: query.value))
        }
        components.queryItems = items
        guard let url = components.url else { throw DirectoryError.invalidRequest }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    nonisolated private static let userAgent = "Airwave/0.1 (+https://github.com/JoAz111/airwave)"

    nonisolated private static func liveLoad(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DirectoryError.invalidResponse }
        return (data, http)
    }
}

private extension RadioBrowserClient {
    enum DirectoryError: Error {
        case invalidRequest
        case invalidResponse
        case server(Int)
        case noMirrors
    }

    struct Record: Decodable {
        let stationuuid: String
        let name: String
        let urlResolved: String
        let homepage: String?
        let favicon: String?
        let tags: String?
        let country: String?
        let countrycode: String?
        let codec: String?
        let bitrate: Int?
        let hls: Int?
        let votes: Int?
        let lastcheckok: Int?

        enum CodingKeys: String, CodingKey {
            case stationuuid, name, homepage, favicon, tags, country, countrycode, codec, bitrate, hls, votes, lastcheckok
            case urlResolved = "url_resolved"
        }

        var station: Station? {
            guard
                lastcheckok == 1,
                let id = UUID(uuidString: stationuuid),
                let streamURL = URL(string: urlResolved),
                ["http", "https"].contains(streamURL.scheme?.lowercased() ?? "")
            else { return nil }

            return Station(
                id: id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                country: country,
                countryCode: countrycode,
                tags: (tags ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                homepageURL: homepage.flatMap(URL.init(string:)),
                faviconURL: favicon.flatMap(URL.init(string:)),
                sources: [StationSource(url: streamURL, codec: codec, bitrate: bitrate, isHLS: hls == 1)],
                votes: votes ?? 0
            )
        }
    }
}
