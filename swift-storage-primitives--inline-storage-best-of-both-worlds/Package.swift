// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "inline-storage-best-of-both-worlds",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "inline-storage-best-of-both-worlds",
            swiftSettings: [
                .enableExperimentalFeature("NonescapableTypes"),
            ]
        )
    ]
)
