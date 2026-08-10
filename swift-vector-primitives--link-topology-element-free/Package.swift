// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "link-topology-element-free",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(path: "../../../swift-vector-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "link-topology-element-free",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Vector Primitives", package: "swift-vector-primitives"),
            ]
        )
    ]
)
