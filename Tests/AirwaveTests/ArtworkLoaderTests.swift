import AppKit
import Foundation
import Testing
@testable import Airwave

@MainActor
struct ArtworkLoaderTests {
    @Test
    func discoversRelativeHomepageIconsRegardlessOfAttributeOrder() {
        let html = """
        <html><head>
        <link href="/images/touch.png" sizes="180x180" rel="apple-touch-icon">
        <link REL='shortcut icon' HREF='icons/favicon.ico'>
        </head></html>
        """

        let urls = ArtworkLoader.iconURLs(
            in: html,
            baseURL: URL(string: "https://radio.example/shows/")!
        )

        #expect(urls == [
            URL(string: "https://radio.example/images/touch.png")!,
            URL(string: "https://radio.example/shows/icons/favicon.ico")!
        ])
    }

    @Test
    func rejectsTinyStationArtwork() throws {
        let image = image(size: NSSize(width: 32, height: 32)) {
            NSColor.systemRed.setFill()
            NSRect(x: 0, y: 0, width: 32, height: 32).fill()
        }
        let data = try #require(pngData(for: image))

        #expect(!ArtworkLoader.isUsableStationArtwork(data))
    }

    @Test
    func rejectsExtremeAspectRatioArtwork() throws {
        let image = image(size: NSSize(width: 320, height: 40)) {
            NSColor.systemBlue.setFill()
            NSRect(x: 0, y: 0, width: 320, height: 40).fill()
        }
        let data = try #require(pngData(for: image))

        #expect(!ArtworkLoader.isUsableStationArtwork(data))
    }

    @Test
    func rejectsNarrowMalformedArtwork() throws {
        let image = image(size: NSSize(width: 256, height: 256)) {
            NSColor.black.setFill()
            NSRect(x: 118, y: 0, width: 20, height: 256).fill()
        }
        let data = try #require(pngData(for: image))

        #expect(!ArtworkLoader.isUsableStationArtwork(data))
    }

    @Test
    func acceptsSubstantialSquareArtwork() throws {
        let image = image(size: NSSize(width: 256, height: 256)) {
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: 256, height: 256).fill()
            NSColor.systemBlue.setFill()
            NSBezierPath(ovalIn: NSRect(x: 38, y: 38, width: 180, height: 180)).fill()
        }
        let data = try #require(pngData(for: image))

        #expect(ArtworkLoader.isUsableStationArtwork(data))
    }

    @Test
    func downsampledArtworkFitsPixelBudgetAndReportsDecodedCost() throws {
        let source = image(size: NSSize(width: 1_024, height: 512)) {
            NSColor.systemPurple.setFill()
            NSRect(x: 0, y: 0, width: 1_024, height: 512).fill()
        }
        let tiffData = try #require(source.tiffRepresentation)

        let decoded = try #require(
            ArtworkLoader.decode(tiffData, maxPixelSize: 256)
        )

        #expect(decoded.pixelWidth == 256)
        #expect(decoded.pixelHeight == 128)
        #expect(decoded.cost == decoded.bytesPerRow * decoded.pixelHeight)
        #expect(decoded.cost <= 256 * 128 * 4)
    }

    private func image(size: NSSize, drawing: () -> Void) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill(using: .copy)
        drawing()
        image.unlockFocus()
        return image
    }

    private func pngData(for image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
