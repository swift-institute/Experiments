// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "contiguous-protocol-escapable",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "contiguous-protocol-escapable",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
