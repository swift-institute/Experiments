// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "mutator-modify-across-quadrants",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "mutator-modify-across-quadrants",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        ),
        .target(
            name: "MutableLib",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        ),
        .executableTarget(
            name: "MutableConsumer",
            dependencies: ["MutableLib"],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        ),
    ]
)
