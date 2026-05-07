// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "result-builder-map-investigation",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-primitives/swift-standard-library-extensions"),
    ],
    targets: [
        .executableTarget(
            name: "result-builder-map-investigation",
            dependencies: [
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
            ]
        )
    ]
)
