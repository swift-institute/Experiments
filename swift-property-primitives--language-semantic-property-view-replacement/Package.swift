// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "language-semantic-property-view-replacement",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "language-semantic-property-view-replacement",
            swiftSettings: [
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
