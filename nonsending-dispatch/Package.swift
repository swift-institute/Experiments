// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "nonsending-dispatch",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "nonsending-dispatch",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        )
    ]
)
