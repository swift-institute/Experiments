// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "escapable-protocol-cross-module",
    platforms: [.macOS(.v26)],
    targets: [
        // Simulates swift-path-primitives: defines Path, Path.View, Path.`Protocol`
        .target(
            name: "PathPrimitives",
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
        // Simulates swift-iso-9945: conforms Path.View to Path.`Protocol` from another module
        .executableTarget(
            name: "escapable-protocol-cross-module",
            dependencies: ["PathPrimitives"],
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
    ]
)
