// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "lazy-pipeline-release-mode",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "lazy-pipeline-release-mode",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
                .enableExperimentalFeature("LifetimeDependence"),
            ]
        )
    ]
)
