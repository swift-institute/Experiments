// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "noncopyable-path-composed-ops",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "noncopyable-path-composed-ops",
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
