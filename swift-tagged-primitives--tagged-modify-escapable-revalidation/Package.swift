// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "tagged-modify-escapable-revalidation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "tagged-modify-escapable-revalidation",
            swiftSettings: [
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
