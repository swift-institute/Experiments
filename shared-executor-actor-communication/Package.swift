// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "shared-executor-actor-communication",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "shared-executor-actor-communication",
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        )
    ]
)
