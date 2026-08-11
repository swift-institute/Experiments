// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "dynamic-member-lookup-quadrants",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "dynamic-member-lookup-quadrants",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
