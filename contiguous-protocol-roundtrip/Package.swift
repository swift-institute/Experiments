// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "contiguous-protocol-roundtrip",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "contiguous-protocol-roundtrip",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
