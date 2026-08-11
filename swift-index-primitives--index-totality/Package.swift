// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "index-totality",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "index-totality", targets: ["index-totality"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-property-primitives.git", branch: "main"),
        .package(path: "../../../swift-index-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "index-totality",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ],
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableExperimentalFeature("ValueGenerics"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
    ]
)
