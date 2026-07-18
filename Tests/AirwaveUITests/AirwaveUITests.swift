import AppKit
import SwiftUI
import Testing
@testable import Airwave

@MainActor
@Suite(.serialized)
struct AirwaveUITests {
    @Test
    func primaryPlayerButtonUsesSharedRadioMetricsAndLabels() {
        #expect(PlayerPrimaryButton.compactDiameter == 40)
        #expect(PlayerPrimaryButton.expandedDiameter == 56)
        #expect(PlayerPrimaryButton.actionLabel(isPlaybackActive: false) == "Play live")
        #expect(PlayerPrimaryButton.actionLabel(isPlaybackActive: true) == "Stop")
    }

    @Test
    func expandedPlayerLayoutKeepsContentInsideCompactWindows() {
        let compact = ExpandedPlayerLayout(availableSize: CGSize(width: 560, height: 520))
        let regular = ExpandedPlayerLayout(availableSize: CGSize(width: 700, height: 660))

        #expect(compact.contentWidth == 492.8)
        #expect(compact.artworkSize == 220)
        #expect(compact.artworkSize < regular.artworkSize)
        #expect(regular.contentWidth == 500)
        #expect(regular.artworkSize == 248)
        #expect(compact.titlebarClearance > compact.bottomInset)
    }

    @Test
    func oversizedFlagsStayInsideTheirGridCells() throws {
        let view = HStack(spacing: 12) {
            CountryFlagCardContent(
                country: country(code: "AA", name: "Left"),
                flagImage: solidImage(color: .systemRed, size: 640)
            )
            .frame(width: 150, height: 150)

            CountryFlagCardContent(
                country: country(code: "BB", name: "Right"),
                flagImage: solidImage(color: .systemBlue, size: 640)
            )
            .frame(width: 150, height: 150)
        }
        .frame(width: 312, height: 150)

        let size = NSSize(width: 312, height: 150)
        let bitmap = render(view, size: size)
        let gapColor = try #require(color(at: NSPoint(x: 155, y: 75), in: bitmap, size: size))

        #expect(abs(gapColor.redComponent - gapColor.greenComponent) < 0.03)
        #expect(abs(gapColor.greenComponent - gapColor.blueComponent) < 0.03)
    }

    @Test
    func nativeLibrarySelectorActivatesCountries() async throws {
        let model = makeModel()
        let hostingView = host(
            ZStack {
                LibraryTabBar(model: model)
                DecoySegmentedControl()
                    .frame(width: 1, height: 1)
            },
            size: NSSize(width: 390, height: 44)
        )
        let selector = try #require(
            descendants(of: NSSegmentedControl.self, in: hostingView)
                .first { $0.accessibilityIdentifier() == "airwave.library-selector" }
        )

        selector.selectedSegment = 1
        selector.sendAction(selector.action, to: selector.target)
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.libraryMode == .countries)
    }

    @Test
    func nativeLibrarySelectorUsesLargeIconSegments() throws {
        let hostingView = host(
            ZStack {
                LibraryTabBar(model: makeModel())
                DecoySegmentedControl()
                    .frame(width: 1, height: 1)
            },
            size: NSSize(width: 390, height: 44)
        )
        let selectors = descendants(of: NSSegmentedControl.self, in: hostingView)
        #expect(selectors.count == 2)
        let selector = try #require(
            selectors.first { $0.accessibilityIdentifier() == "airwave.library-selector" }
        )
        let decoy = try #require(selectors.first { $0 !== selector })

        #expect(selector.segmentCount == 4)
        #expect(selector.controlSize == .large)
        #expect(selector.accessibilityIdentifier() == "airwave.library-selector")
        let expectedSymbols = [
            "rectangle.grid.2x2",
            "globe.americas.fill",
            "star",
            "clock"
        ]
        for (index, expectedSymbol) in expectedSymbols.enumerated() {
            let image = try #require(selector.image(forSegment: index))
            #expect(image.accessibilityDescription == expectedSymbol)
        }
        #expect(decoy.segmentCount == 1)
        #expect(decoy.accessibilityIdentifier() != "airwave.library-selector")
        #expect(decoy.image(forSegment: 0) == nil)
    }

    private func country(code: String, name: String) -> Country {
        Country(code: code, name: name, stationCount: 10, isLocal: false)
    }

    private func solidImage(color: NSColor, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.unlockFocus()
        return image
    }

    private func render<V: View>(_ view: V, size: NSSize) -> NSBitmapImageRep {
        let hostingView = host(view, size: size)
        let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)!
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        return bitmap
    }

    private func host<V: View>(_ view: V, size: NSSize) -> NSHostingView<V> {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        return hostingView
    }

    private func descendant<T: NSView>(of type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let match = descendant(of: type, in: subview) { return match }
        }
        return nil
    }

    private func descendants<T: NSView>(of type: T.Type, in view: NSView) -> [T] {
        var matches = (view as? T).map { [$0] } ?? []
        for subview in view.subviews {
            matches.append(contentsOf: descendants(of: type, in: subview))
        }
        return matches
    }

    private struct DecoySegmentedControl: NSViewRepresentable {
        func makeNSView(context: Context) -> NSSegmentedControl {
            NSSegmentedControl(
                labels: ["Decoy"],
                trackingMode: .selectOne,
                target: nil,
                action: nil
            )
        }

        func updateNSView(_ control: NSSegmentedControl, context: Context) {}
    }

    private func color(
        at point: NSPoint,
        in bitmap: NSBitmapImageRep,
        size: NSSize
    ) -> NSColor? {
        let xScale = CGFloat(bitmap.pixelsWide) / size.width
        let yScale = CGFloat(bitmap.pixelsHigh) / size.height
        return bitmap.colorAt(
            x: Int(point.x * xScale),
            y: Int(point.y * yScale)
        )
    }

    private func makeModel() -> AppModel {
        var preferences = AirwavePreferences()
        preferences.lastStation = Self.station
        preferences.volume = 0.7
        return AppModel(
            search: UISearchFake(),
            countries: UICountryFake(),
            player: UIPlayerFake(),
            preferences: UIPreferencesFake(value: preferences),
            locale: Locale(identifier: "en_IL"),
            localCountryCode: "IL"
        )
    }

    private static let station = Station(
        id: UUID(),
        name: "Capital FM London",
        country: "United Kingdom",
        countryCode: "GB",
        tags: ["pop"],
        homepageURL: nil,
        faviconURL: nil,
        sources: [StationSource(
            url: URL(string: "https://example.com/live")!,
            codec: "MP3",
            bitrate: 128,
            isHLS: false
        )],
        votes: 1
    )
}

private actor UISearchFake: StationSearching {
    func explore(countryCode: String?) async throws -> [Station] { [] }
    func search(_ query: String) async throws -> [Station] { [] }
    func stations(in countryCode: String, matching query: String) async throws -> [Station] { [] }
}

private actor UICountryFake: CountryLoading {
    func load(locale: Locale, localCode: String?) async -> [Country] { [] }
}

@MainActor
private final class UIPlayerFake: RadioPlaying {
    var state: PlaybackState = .idle
    var metadata: NowPlayingMetadata?
    var volume: Float = 0
    var onStateChange: ((PlaybackState) -> Void)?
    var onMetadataChange: ((NowPlayingMetadata?) -> Void)?
    func load(_ station: Station) {}
    func stop() {}
}

@MainActor
private final class UIPreferencesFake: PreferencesStoring {
    var value: AirwavePreferences
    init(value: AirwavePreferences) { self.value = value }
    func load() -> AirwavePreferences { value }
    func save(_ preferences: AirwavePreferences) { value = preferences }
}
