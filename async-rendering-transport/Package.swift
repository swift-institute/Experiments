// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "async-rendering-transport",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "async-rendering-transport",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
