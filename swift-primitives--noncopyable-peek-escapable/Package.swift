// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "noncopyable-peek-escapable",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "noncopyable-peek-escapable",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
