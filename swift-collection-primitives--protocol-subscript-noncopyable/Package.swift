// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "protocol-subscript-noncopyable",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "Protocols",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        ),
        .executableTarget(
            name: "Conformers",
            dependencies: ["Protocols"],
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        ),
    ]
)
