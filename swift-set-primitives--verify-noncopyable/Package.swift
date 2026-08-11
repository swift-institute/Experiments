// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "verify-noncopyable",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swift-primitives/swift-hash-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-equation-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "verify-noncopyable",
            dependencies: [
                .product(name: "Set Primitives", package: "swift-set-primitives"),
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
                .product(name: "Equation Primitives", package: "swift-equation-primitives"),
            ]
        )
    ]
)
