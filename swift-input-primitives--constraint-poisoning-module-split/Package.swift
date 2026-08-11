// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "constraint-poisoning-module-split",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "constraint-poisoning-module-split",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
