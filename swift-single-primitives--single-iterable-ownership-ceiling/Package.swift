// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "single-iterable-ownership-ceiling",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "single-iterable-ownership-ceiling",
            dependencies: [
                .product(name: "Single Primitives", package: "swift-single-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
