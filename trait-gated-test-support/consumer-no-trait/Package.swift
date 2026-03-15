// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "consumer-no-trait",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../rendering"),  // NO traits enabled
    ],
    targets: [
        .executableTarget(
            name: "consumer-no-trait",
            dependencies: [
                .product(name: "Rendering Test Support", package: "rendering"),
            ]
        ),
    ]
)
