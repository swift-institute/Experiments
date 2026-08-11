// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "inline-span-property",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "main",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("Span"),
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
