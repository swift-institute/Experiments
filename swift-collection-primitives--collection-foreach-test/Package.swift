// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "collection-foreach-test",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "collection-foreach-test",
            dependencies: [
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
