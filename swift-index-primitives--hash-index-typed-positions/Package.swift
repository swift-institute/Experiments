// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "hash-index-typed-positions",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "hash-index-typed-positions", targets: ["hash-index-typed-positions"])
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swift-primitives/swift-hash-primitives.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "hash-index-typed-positions",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Hash Index Primitives", package: "swift-index-primitives"),
                .product(name: "Hash Primitives", package: "swift-hash-primitives")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
