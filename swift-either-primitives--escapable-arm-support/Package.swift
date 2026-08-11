// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "escapable-arm-support",
    platforms: [.macOS(.v26)],
    products: [
        .library(
            name: "EscapableArmSupport",
            targets: ["EscapableArmSupport"]
        ),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .target(
            name: "EscapableArmSupport",
            dependencies: [
                .product(name: "Either Primitives", package: "swift-either-primitives"),
            ],
            swiftSettings: [.enableExperimentalFeature("Lifetimes")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
