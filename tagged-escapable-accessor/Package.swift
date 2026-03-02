// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "tagged-escapable-accessor",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "TaggedLib"),
    ],
    targets: [
        .target(
            name: "StringLib",
            dependencies: [.product(name: "TaggedLib", package: "TaggedLib")],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("StrictMemorySafety"),
            ]
        ),
        .executableTarget(
            name: "Consumer",
            dependencies: ["StringLib"],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("StrictMemorySafety"),
            ]
        ),
    ]
)
