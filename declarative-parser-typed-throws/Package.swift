// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "declarative-parser-typed-throws",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-primitives/swift-parser-primitives"),
    ],
    targets: [
        .testTarget(
            name: "declarative-parser-typed-throws",
            dependencies: [
                .product(name: "Parser Primitives", package: "swift-parser-primitives"),
            ],
            path: "Tests/declarative-parser-typed-throws"
        )
    ]
)
