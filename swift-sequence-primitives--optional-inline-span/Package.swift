// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "optional-inline-span",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "optional-inline-span",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
