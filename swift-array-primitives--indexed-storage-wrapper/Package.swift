// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "indexed-storage-wrapper",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "IndexedStorageWrapper", targets: ["IndexedStorageWrapper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(path: "../../../swift-array-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "IndexedStorageWrapper",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Array Primitives", package: "swift-array-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
    ]
)
