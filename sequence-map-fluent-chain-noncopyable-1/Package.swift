// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "sequence-map-fluent-chain-noncopyable-1",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "sequence-map-fluent-chain-noncopyable-1",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
