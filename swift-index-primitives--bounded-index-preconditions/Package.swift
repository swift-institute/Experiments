// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "bounded-index-preconditions",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "bounded-index-preconditions", targets: ["bounded-index-preconditions"])
    ],
    dependencies: [
        .package(path: "../../../swift-index-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "bounded-index-preconditions",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("ValueGenerics"),
            ]
        )
    ]
)
