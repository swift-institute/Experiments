// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "collection-iteration-semantics",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "collection-iteration-semantics",
            dependencies: [
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
