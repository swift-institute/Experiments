// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "sequence-foreach-test",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "sequence-foreach-test",
            dependencies: [
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
