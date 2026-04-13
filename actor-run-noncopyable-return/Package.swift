// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "actor-run-noncopyable-return",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "actor-run-noncopyable-return",
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        )
    ]
)
