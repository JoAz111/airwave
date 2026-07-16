<div align="center">

# Airwave

### A tiny, native internet radio player for macOS.

[![Platform](https://img.shields.io/badge/macOS-26%2B-111111?logo=apple)](https://www.apple.com/macos/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-F05138?logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![Status](https://img.shields.io/badge/status-early_development-1671E8)](#status)

Turn the dial. Keep the app out of the way.

</div>

Airwave is a free, open-source radio player built specifically for the Mac. It combines a compact SwiftUI window with a tiny menu-bar controller, giving you fast access to radio stations from around the world without accounts, subscriptions, tracking, or a heavyweight media app.

## What Airwave does

- Searches a global catalog by station, country, language, or genre
- Prefers healthy, high-bitrate streams when multiple sources are available
- Plays and pauses live radio with native `AVPlayer` playback
- Shows live song or program metadata when the station provides it
- Controls app-relative volume from the window or menu bar
- Shows station logos with memory and disk caching
- Remembers favorites, recent stations, the last station, and volume
- Keeps playing when the main window is closed
- Looks and behaves like a macOS 26 app because it is one

## Small by design

Airwave has one job: play internet radio beautifully.

There are no accounts, recommendations, social features, analytics, ads, subscriptions, plug-ins, cross-platform abstractions, or embedded web views. The app uses SwiftUI, AVFoundation, Foundation, and other native Apple frameworks. It has no third-party Swift package dependencies.

## The interface

The main window is a compact station browser with three simple views:

- **Explore** for global search and discovery
- **Favorites** for stations you want to keep
- **Recent** for getting back to something quickly

The now-playing bar stays visible at the bottom and shows the station's live song or program metadata when available. A small menu-bar popover shows the active station, current metadata, play/pause, volume, and a button to reopen Airwave.

## Radio directory

Station discovery is powered by the free and open-source [Radio Browser](https://www.radio-browser.info/) community directory. Airwave filters broken entries, resolves stream URLs, and fails over between public directory mirrors when one is unavailable.

Radio Browser is a community-maintained catalog, so no directory can guarantee every broadcaster or uninterrupted availability. Airwave handles missing artwork, unavailable stations, and network failures without getting in your way.

## Privacy

Airwave itself has no accounts, analytics, advertising SDKs, or telemetry.

Using the app makes network requests to Radio Browser for station data, to station websites for artwork, and to the selected broadcaster for audio. Those services can receive normal connection information such as your IP address and user agent.

## Requirements

- macOS 26 or later
- An internet connection

## Status

Airwave is in early development and is not ready to install yet. The first milestone is a complete, lightweight player with search, favorites, recents, cached artwork, and menu-bar controls.

If that sounds fun, star the repository and follow along.

## Contributing

Airwave is intentionally narrow in scope. Bug fixes, accessibility improvements, native macOS polish, and focused performance work are welcome. Large new feature areas should start with a discussion so the project stays small.

---

<div align="center">
Built for the Mac, for the fun of it.
</div>
