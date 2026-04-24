// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "polling-two-phase-api",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "polling-two-phase-api",
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        )
    ]
)
