// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "typed-index-boundary",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-index-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "typed-index-boundary",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictMemorySafety"),
            ]
        )
    ]
)
