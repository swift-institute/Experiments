// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "inout-value-accessor-copyability-split",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-ownership-primitives")
    ],
    targets: [
        .executableTarget(
            name: "inout-value-accessor-copyability-split",
            dependencies: [
                .product(name: "Ownership Primitives", package: "swift-ownership-primitives")
            ]
        )
    ]
)
