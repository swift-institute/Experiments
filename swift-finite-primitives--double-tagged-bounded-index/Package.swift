// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "double-tagged-bounded-index",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "double-tagged-bounded-index", targets: ["double-tagged-bounded-index"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(path: "../../../swift-finite-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "double-tagged-bounded-index",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        )
    ]
)
