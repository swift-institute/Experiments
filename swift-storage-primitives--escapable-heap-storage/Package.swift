// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "escapable-heap-storage",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "escapable-heap-storage",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("BuiltinModule"),
            ]
        )
    ]
)
