import AppKit
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) { NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
}

@main struct AirwaveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel
    private let artwork = ArtworkLoader()
    @MainActor private static let menuBarIcon: NSImage = {
        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            return image
        }
        return NSImage(
            systemSymbolName: "antenna.radiowaves.left.and.right",
            accessibilityDescription: "Airwave"
        )!
    }()

    init() {
        let directory = RadioBrowserClient()
        let player = RadioPlayer()
        let preferences = PreferencesStore()
        _model = State(initialValue: AppModel(
            search: StationSearchService(directory: directory),
            countries: CountryService(directory: directory),
            player: player,
            preferences: preferences
        ))
    }

    var body: some Scene {
        WindowGroup("Airwave", id: "main") { MainWindowView(model: model, artwork: artwork).frame(idealWidth: 390, idealHeight: 590) }
            .defaultSize(width: 390, height: 590)
            .commands { CommandGroup(replacing: .newItem) {} }
        MenuBarExtra {
            MenuBarPlayerView(model: model, artwork: artwork)
        } label: {
            Image(nsImage: Self.menuBarIcon)
                .accessibilityLabel("Airwave")
        }
        .menuBarExtraStyle(.window)
    }
}
