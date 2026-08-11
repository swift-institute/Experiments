// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "inline-uninitialized",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "inline-uninitialized",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
