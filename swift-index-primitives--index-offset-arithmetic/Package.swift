// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "index-offset-arithmetic",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "index-offset-arithmetic",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives")
            ]
        )
    ]
)
