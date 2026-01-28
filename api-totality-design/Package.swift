// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "api-totality-design",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-primitives")
    ],
    targets: [
        .executableTarget(
            name: "api-totality-design",
            dependencies: [
                .product(name: "Index_Primitives", package: "swift-primitives")
            ]
        )
    ]
)
