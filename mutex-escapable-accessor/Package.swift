// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "mutex-escapable-accessor",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "mutex-escapable-accessor",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
