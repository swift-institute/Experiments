// swift-tools-version: 6.3
import PackageDescription

// Reality-check sub-experiment: drives the production footgun repro against
// the REAL Bit.Index + Tagged Primitives Test Support packages.
let package = Package(
    name: "production-reality-check",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-bit-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(path: "../../../../swift-tagged-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "production-reality-check",
            dependencies: [
                .product(name: "Bit Index Primitives", package: "swift-bit-index-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
                // Test support provides the blanket ExpressibleByIntegerLiteral
                .product(name: "Tagged Primitives Test Support", package: "swift-tagged-primitives"),
            ]
        )
    ]
)
