// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "tagged-view-protocol",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "tagged-view-protocol",
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
