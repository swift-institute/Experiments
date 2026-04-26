// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "hasher-pattern-mutator-isolation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "hasher-pattern-mutator-isolation",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
