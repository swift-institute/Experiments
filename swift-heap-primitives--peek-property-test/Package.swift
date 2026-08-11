// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "peek-property-test",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../"),
        .package(url: "https://github.com/swift-primitives/swift-property-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "peek-property-test",
            dependencies: [
                .product(name: "Heap Primitives", package: "swift-heap-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
