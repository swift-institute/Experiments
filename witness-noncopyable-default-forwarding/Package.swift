// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "witness-noncopyable-default-forwarding",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "witness-noncopyable-default-forwarding",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
            ]
        )
    ]
)
