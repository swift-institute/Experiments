// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "nested-read-escapable-composition",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "nested-read-escapable-composition",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
    ]
)
