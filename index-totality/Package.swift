// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "index-totality",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-primitives")
    ],
    targets: [
        .executableTarget(
            name: "index-totality",
            dependencies: [
                .product(name: "Index_Primitives", package: "swift-primitives")
            ]
        )
    ]
)
