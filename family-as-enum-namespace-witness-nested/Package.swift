// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "family-as-enum-namespace-witness-nested",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "family-as-enum-namespace-witness-nested",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        )
    ]
)
