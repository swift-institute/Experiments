// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "parser-as-witness-namespace-collision",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "parser-as-witness-namespace-collision",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        )
    ]
)
