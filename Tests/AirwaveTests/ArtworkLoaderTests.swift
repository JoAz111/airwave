import Foundation
import Testing
@testable import Airwave

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
}
