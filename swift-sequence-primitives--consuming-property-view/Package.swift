// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "consuming-property-view",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "consuming-property-view",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("LifetimeDependenceDiagnosticsForReturnedConsuming"),
                .strictMemorySafety(),
            ]
        )
    ]
)
