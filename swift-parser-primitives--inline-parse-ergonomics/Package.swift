// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "inline-parse-ergonomics",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swift-primitives/swift-ascii-parser-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-byte-parser-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-collection-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-input-primitives.git", branch: "main"),
    ],
    targets: [
        .testTarget(
            name: "InlineParseErgonomicsTests",
            dependencies: [
                .product(name: "Parser Primitives", package: "swift-parser-primitives"),
                .product(name: "Parser Primitives Test Support", package: "swift-parser-primitives"),
                .product(name: "ASCII Decimal Parser Primitives", package: "swift-ascii-parser-primitives"),
                .product(name: "Byte Parser Primitives", package: "swift-byte-parser-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
            ],
            path: "Tests"
        ),
    ]
)
