// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "pointer-nonescapable-storage",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "pointer-nonescapable-storage",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("RawLayout"),
                .strictMemorySafety(),
            ]
        )
    ]
)
