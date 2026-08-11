// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "two-tier-borrowing-overloads",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "two-tier-borrowing-overloads",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("LifetimeDependence"),
            ]
        )
    ]
)
