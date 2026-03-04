// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "witness-macro-noncopyable-feasibility",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "witness-macro-noncopyable-feasibility",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
            ]
        )
    ]
)
