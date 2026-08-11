// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "index-totality",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "index-totality", targets: ["index-totality"])
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "index-totality",
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
