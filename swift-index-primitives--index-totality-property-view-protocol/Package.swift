// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "index-totality-property-view-protocol",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "index-totality-property-view-protocol",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives")
            ]
        )
    ]
)
