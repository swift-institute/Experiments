// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "sync-overload-resolution",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "SyncOverloadResolution",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        )
    ]
)
