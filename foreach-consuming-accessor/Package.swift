// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "foreach-consuming-accessor-test",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "foreach-consuming-accessor-test",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
