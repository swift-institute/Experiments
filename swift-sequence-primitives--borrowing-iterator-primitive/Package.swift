// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "borrowing-iterator-primitive",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "borrowing-iterator-primitive",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("LifetimeDependence"),
            ]
        )
    ]
)
