// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "tagged-string-crossmodule",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "TaggedLib",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("StrictMemorySafety"),
            ]
        ),
        .target(
            name: "StringLib",
            dependencies: ["TaggedLib"],
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
