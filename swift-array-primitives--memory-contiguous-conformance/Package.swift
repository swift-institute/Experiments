// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "memory-contiguous-conformance",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "main",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("AddressableTypes"),
                .enableExperimentalFeature("LifetimeDependence"),
                .strictMemorySafety(),
            ]
        ),
    ]
)
