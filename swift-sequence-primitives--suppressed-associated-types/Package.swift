// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "suppressed-associated-types",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "suppressed-associated-types",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("LifetimeDependence"),
            ]
        )
    ]
)
