// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "tagged-view-struct",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "tagged-view-struct",
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
