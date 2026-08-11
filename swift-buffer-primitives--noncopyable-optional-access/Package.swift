// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "noncopyable-optional-access",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "noncopyable-optional-access",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
