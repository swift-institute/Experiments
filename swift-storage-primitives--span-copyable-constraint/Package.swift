// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "span-copyable-constraint",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "span-copyable-constraint",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        )
    ]
)
