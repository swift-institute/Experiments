// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "actor-run-sending-closure",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "actor-run-sending-closure",
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        )
    ]
)
