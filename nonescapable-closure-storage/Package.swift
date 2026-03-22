// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "nonescapable-closure-storage",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "nonescapable-closure-storage",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
