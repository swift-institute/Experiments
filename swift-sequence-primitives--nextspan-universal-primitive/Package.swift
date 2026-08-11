// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "nextspan-universal-primitive",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "nextspan-universal-primitive",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
