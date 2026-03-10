// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "escapable-accessor-patterns",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "escapable-accessor-patterns",
            swiftSettings: [.enableExperimentalFeature("Lifetimes")]
        )
    ]
)
