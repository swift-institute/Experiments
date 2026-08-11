// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "inline-span-investigation",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "main",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("AddressableTypes"),
                .enableExperimentalFeature("LifetimeDependence"),
                .unsafeFlags(["-enable-experimental-feature", "BuiltinModule"]),
            ]
        ),
    ]
)
