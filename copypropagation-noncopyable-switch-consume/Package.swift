// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "copypropagation-noncopyable-switch-consume",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "copypropagation-noncopyable-switch-consume",
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
