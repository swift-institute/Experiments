// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "escapable-blocked",
    platforms: [.macOS(.v26)],
    products: [
        .library(
            name: "EscapableBlocked",
            targets: ["EscapableBlocked"]
        ),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .target(
            name: "EscapableBlocked",
            dependencies: [
                .product(name: "Product Primitives", package: "swift-product-primitives"),
            ],
            swiftSettings: [.enableExperimentalFeature("Lifetimes")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
