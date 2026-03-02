// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "nonsending-sendable-iterator",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "nonsending-sendable-iterator",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        )
    ]
)
