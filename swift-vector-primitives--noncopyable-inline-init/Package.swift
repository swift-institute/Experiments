// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "noncopyable-inline-init",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "noncopyable-inline-init",
            swiftSettings: [
                .enableExperimentalFeature("ValueGenerics"),
                .enableExperimentalFeature("RawLayout"),
            ]
        )
    ]
)
