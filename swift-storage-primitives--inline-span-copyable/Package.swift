// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "inline-span-copyable",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "inline-span-copyable",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
