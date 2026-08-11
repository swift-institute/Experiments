// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "exclusivity-direct-chain-test",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ordinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-cardinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-hash-table-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-sequence-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-property-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "exclusivity-direct-chain-test",
            dependencies: [
                .product(name: "Buffer Primitives", package: "swift-buffer-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
                .product(name: "Hash Table Primitives", package: "swift-hash-table-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        )
    ]
)
