// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "suppressed-escapable-associated-types",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "suppressed-escapable-associated-types",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
