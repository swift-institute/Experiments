// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "result-builder-parameter-packs-narity",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "result-builder-parameter-packs-narity",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        )
    ]
)
