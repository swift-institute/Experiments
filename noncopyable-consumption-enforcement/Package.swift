// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "noncopyable-consumption-enforcement",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "noncopyable-consumption-enforcement",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        )
    ]
)
