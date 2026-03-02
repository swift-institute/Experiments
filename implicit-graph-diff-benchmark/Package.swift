// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "implicit-graph-diff-benchmark",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "implicit-graph-diff-benchmark",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        )
    ]
)
