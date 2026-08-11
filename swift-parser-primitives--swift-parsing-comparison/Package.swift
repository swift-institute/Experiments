// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-parsing-comparison",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.13.0"),
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "swift-parsing-comparison",
            dependencies: [
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "Parser Primitives", package: "swift-parser-primitives"),
                .product(name: "Parser Primitives Test Support", package: "swift-parser-primitives"),
            ]
        )
    ]
)
