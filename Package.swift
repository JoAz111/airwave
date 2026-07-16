// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Airwave",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Airwave", targets: ["Airwave"])
    ],
    targets: [
        .executableTarget(name: "Airwave"),
        .testTarget(name: "AirwaveTests", dependencies: ["Airwave"])
    ]
)
