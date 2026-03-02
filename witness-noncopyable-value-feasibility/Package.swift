// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "witness-noncopyable-value-feasibility",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "witness-noncopyable-value-feasibility",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
            ]
        )
    ]
)
