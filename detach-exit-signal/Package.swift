// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "detach-exit-signal",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "detach-exit-signal",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
