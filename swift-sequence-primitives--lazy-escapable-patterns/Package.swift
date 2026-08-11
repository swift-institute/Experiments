// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "lazy-escapable-patterns",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "lazy-escapable-patterns",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("LifetimeDependenceDiagnosticsForReturnedConsuming"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("BuiltinModule"),
                .strictMemorySafety(),
            ]
        )
    ]
)
