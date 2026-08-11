// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "foreach-convenience-discovery",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "foreach-convenience-discovery",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
