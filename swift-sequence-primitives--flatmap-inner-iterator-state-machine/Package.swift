// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "flatmap-inner-iterator-state-machine",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "flatmap-inner-iterator-state-machine",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
