// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "bitvector-slot-tracking",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-bit-vector-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-bit-index-primitives.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "bitvector-slot-tracking",
            dependencies: [
                .product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),
                .product(name: "Bit Index Primitives Test Support", package: "swift-bit-index-primitives")
            ],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout")
            ]
        )
    ]
)
