// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "stream-isolation-preservation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "stream-isolation-preservation",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        )
    ]
)
