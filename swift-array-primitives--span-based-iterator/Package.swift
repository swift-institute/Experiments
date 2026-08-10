// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "span-based-iterator",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "main",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .swiftLanguageMode(.v6),
                .unsafeFlags(["-strict-memory-safety"]),
            ]
        )
    ]
)
