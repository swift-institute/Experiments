// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "BufferPackage",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Buffer", targets: ["Buffer"])
    ],
    dependencies: [
        .package(path: "../ElementPackage"),
        .package(path: "../StoragePackage"),
    ],
    targets: [
        .target(
            name: "Buffer",
            dependencies: [
                .product(name: "Element", package: "ElementPackage"),
                .product(name: "Storage", package: "StoragePackage"),
            ]
        )
    ]
)
