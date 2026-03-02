// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "lazy-sequence-operator-unification",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "lazy-sequence-operator-unification",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("NonisolatedNonsendingByDefault"),
            ]
        )
    ]
)
