// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "capability-lift-pattern",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "capability-lift-pattern",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
