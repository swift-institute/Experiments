// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "consumer",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../rendering", traits: ["SnapshotTesting"]),
    ],
    targets: [
        .executableTarget(
            name: "consumer",
            dependencies: [
                .product(name: "Rendering Test Support", package: "rendering"),
            ]
        ),
    ]
)
