// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "collection-sequence-detachment",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "collection-sequence-detachment",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
