import Foundation
import Testing
@testable import Airwave

struct RadioBrowserClientTests {
    @Test
    func decodesHealthyStationAndBuildsBoundedQuery() async throws {
        let recorder = RequestRecorder(responses: [.success(Self.stationJSON)])
        let client = RadioBrowserClient(
            mirrors: [URL(string: "https://de1.api.radio-browser.info")!],
            load: { try await recorder.load($0) }
        )

        let stations = try await client.stations(
            matching: RadioBrowserQuery(field: .name, value: "FIP", limit: 30, order: "votes", reverse: true)
        )

        #expect(stations.count == 1)
        #expect(stations[0].name == "FIP")
        #expect(stations[0].primarySource?.bitrate == 192)
        let request = try #require(await recorder.requests.first)
        let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.contains(URLQueryItem(name: "name", value: "FIP")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "hidebroken", value: "true")) == true)
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("Airwave/") == true)
    }

    @Test
    func retriesOneDifferentMirrorAfterServerFailure() async throws {
        let recorder = RequestRecorder(responses: [.serverError, .success(Self.stationJSON)])
        let client = RadioBrowserClient(
            mirrors: [
                URL(string: "https://de1.api.radio-browser.info")!,
                URL(string: "https://nl1.api.radio-browser.info")!
            ],
            load: { try await recorder.load($0) }
        )

        _ = try await client.stations(
            matching: RadioBrowserQuery(field: nil, value: "", limit: 100, order: "clickcount", reverse: true)
        )

        #expect(await recorder.requests.map(\.url?.host) == ["de1.api.radio-browser.info", "nl1.api.radio-browser.info"])
    }

    @Test
    func decodesCountryCodesWithStringOrIntegerCounts() async throws {
        let recorder = RequestRecorder(responses: [.success(Self.countryCodesJSON)])
        let client = RadioBrowserClient(
            mirrors: [URL(string: "https://de1.api.radio-browser.info")!],
            load: { try await recorder.load($0) }
        )

        let entries = try await client.countryCodes()

        #expect(entries == [
            CountryDirectoryEntry(code: "IL", stationCount: 4),
            CountryDirectoryEntry(code: "FR", stationCount: 6)
        ])
        let request = try #require(await recorder.requests.first)
        #expect(request.url?.path == "/json/countrycodes")
    }

    @Test
    func stationQueryIncludesCountryCode() async throws {
        let recorder = RequestRecorder(responses: [.success(Self.stationJSON)])
        let client = RadioBrowserClient(
            mirrors: [URL(string: "https://de1.api.radio-browser.info")!],
            load: { try await recorder.load($0) }
        )

        _ = try await client.stations(matching: RadioBrowserQuery(
            field: .name,
            value: "jazz",
            countryCode: "IL",
            limit: 30,
            order: "votes",
            reverse: true
        ))

        let request = try #require(await recorder.requests.first)
        let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.contains(URLQueryItem(name: "countrycode", value: "IL")) == true)
    }

    private static let stationJSON = Data(#"""
    [{
      "stationuuid":"110e57c5-0601-11e8-ae97-52543be04c81",
      "name":"FIP",
      "url_resolved":"https://example.com/live.aac",
      "homepage":"https://www.radiofrance.fr/fip",
      "favicon":"https://example.com/fip.png",
      "tags":"eclectic,jazz",
      "country":"France",
      "countrycode":"FR",
      "codec":"AAC",
      "bitrate":192,
      "hls":0,
      "votes":42,
      "lastcheckok":1
    }]
    """#.utf8)

    private static let countryCodesJSON = Data(#"""
    [
      {"name":"IL","stationcount":"4"},
      {"name":"FR","stationcount":6}
    ]
    """#.utf8)
}

private actor RequestRecorder {
    enum Response: Sendable {
        case success(Data)
        case serverError
    }

    private(set) var requests: [URLRequest] = []
    private var responses: [Response]

    init(responses: [Response]) {
        self.responses = responses
    }

    func load(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let response = responses.removeFirst()
        let statusCode: Int
        let data: Data
        switch response {
        case let .success(value):
            statusCode = 200
            data = value
        case .serverError:
            statusCode = 503
            data = Data()
        }
        return (
            data,
            HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        )
    }
}
