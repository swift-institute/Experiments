// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "async-let-noncopyable-transfer",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "async-let-noncopyable-transfer",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        )
    ]
)
