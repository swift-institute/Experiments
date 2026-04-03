// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "nonescapable-patterns",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "PathPrimitivesLib",
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
        .target(
            name: "NonescapablePatterns",
            dependencies: ["PathPrimitivesLib"],
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("RawLayout"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("NonisolatedNonsendingByDefault"),
            ]
        ),
    ]
)
