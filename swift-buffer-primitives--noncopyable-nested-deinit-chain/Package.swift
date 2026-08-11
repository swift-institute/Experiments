// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-nested-deinit-chain",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "LocalPackages/ElementPackage"),
        .package(path: "LocalPackages/StoragePackage"),
    ],
    targets: [
        .executableTarget(
            name: "noncopyable-nested-deinit-chain",
            dependencies: [
                .product(name: "Element", package: "ElementPackage"),
                .product(name: "Storage", package: "StoragePackage"),
            ]
        )
    ]
)
