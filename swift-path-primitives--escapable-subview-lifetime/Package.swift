// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "escapable-subview-lifetime",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "escapable-subview-lifetime",
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
