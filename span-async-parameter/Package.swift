// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "span-async-parameter",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "span-async-parameter",
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        )
    ]
)
