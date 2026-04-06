// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "sending-vs-sendable-structured-concurrency",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "sending-vs-sendable-structured-concurrency",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
