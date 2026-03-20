// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "StoragePackage",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Storage", targets: ["Storage"])
    ],
    dependencies: [
        .package(path: "../ElementPackage")
    ],
    targets: [
        .target(
            name: "Storage",
            dependencies: [
                .product(name: "Element", package: "ElementPackage")
            ],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        )
    ]
)
