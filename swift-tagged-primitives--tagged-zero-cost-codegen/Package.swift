// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "tagged-zero-cost-codegen",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swift-primitives/swift-carrier-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "tagged-zero-cost-codegen",
            dependencies: [
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
                .product(name: "Carrier Primitives Standard Library Integration", package: "swift-carrier-primitives"),
                .product(name: "Tagged Primitives Standard Library Integration", package: "swift-tagged-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
