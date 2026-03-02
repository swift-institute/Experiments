// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "escapable-lazy-sequence-borrowing",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "escapable-lazy-sequence-borrowing",
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
