// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "sequence-operations-discovery",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "sequence-operations-discovery",
            dependencies: [
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
