// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "wrapper-init-inlinability-cost",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "Wrappers",
            swiftSettings: [
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
        .executableTarget(
            name: "Benchmark",
            dependencies: ["Wrappers"],
            swiftSettings: [
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
    ]
)
