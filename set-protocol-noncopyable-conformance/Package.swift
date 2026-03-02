// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "set-protocol-noncopyable-conformance",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "set-protocol-noncopyable-conformance",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
