// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "mutablespan-async-read",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "mutablespan-async-read",
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        )
    ]
)
