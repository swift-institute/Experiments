// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "self-projection-default-pattern",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "self-projection-default-pattern",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
