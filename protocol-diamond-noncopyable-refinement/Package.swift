// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "protocol-diamond-noncopyable-refinement",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "protocol-diamond-noncopyable-refinement",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
            ]
        )
    ]
)
