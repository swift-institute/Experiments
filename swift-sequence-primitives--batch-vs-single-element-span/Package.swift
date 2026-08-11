// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "batch-vs-single-element-span",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "batch-vs-single-element-span",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
