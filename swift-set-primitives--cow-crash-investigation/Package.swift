// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "cow-crash-investigation",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "cow-crash-investigation",
            dependencies: [
                .product(name: "Set Primitives", package: "swift-set-primitives"),
            ]
        )
    ]
)
