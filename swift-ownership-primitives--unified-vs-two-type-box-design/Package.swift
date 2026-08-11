// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "unified-vs-two-type-box-design",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "unified-vs-two-type-box-design",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
