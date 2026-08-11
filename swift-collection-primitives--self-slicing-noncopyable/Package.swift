// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "self-slicing-noncopyable",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "self-slicing-noncopyable",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
