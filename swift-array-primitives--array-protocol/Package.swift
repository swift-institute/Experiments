// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "array-protocol",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "array-protocol",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
