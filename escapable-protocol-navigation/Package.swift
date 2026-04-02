// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "escapable-protocol-navigation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "escapable-protocol-navigation",
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
