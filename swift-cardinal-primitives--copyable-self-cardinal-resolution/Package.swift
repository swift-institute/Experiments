// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "copyable-self-cardinal-resolution",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .target(
            name: "QLib",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("LifetimeDependence"),
            ]
        ),
        .target(
            name: "CardinalSLILib",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("LifetimeDependence"),
            ]
        ),
        .executableTarget(
            name: "copyable-self-cardinal-resolution",
            dependencies: [
                "QLib",
                // NOTE: We DO NOT directly depend on Cardinal Primitives Core
                // or Cardinal Primitives Standard Library Integration. Both
                // reach this target only TRANSITIVELY via Cardinal Primitives
                // (the umbrella). This mirrors Sequence Hint's deps in
                // sequence-primitives, where Cardinal SLI is reached via
                // Property Primitives + Index Primitives transitive re-exports.
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("LifetimeDependence"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
