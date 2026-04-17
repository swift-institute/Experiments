// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "sending-closure-capture-from-isolated-scope",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "sending-closure-capture-from-isolated-scope",
            swiftSettings: [
                // Match the io-algebra experiment's settings so we
                // reproduce the exact region-checker behavior.
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
