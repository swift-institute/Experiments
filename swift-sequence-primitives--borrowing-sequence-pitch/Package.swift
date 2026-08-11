// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "borrowing-sequence-pitch",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "borrowing-sequence-pitch",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("AddressableTypes"),
                .enableExperimentalFeature("BuiltinModule"),
            ]
        )
    ]
)
