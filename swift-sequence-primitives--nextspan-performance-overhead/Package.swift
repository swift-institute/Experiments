// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "nextspan-performance-overhead",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "nextspan-performance-overhead",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
