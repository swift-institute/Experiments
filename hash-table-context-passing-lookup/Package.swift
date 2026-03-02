// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "hash-table-context-passing-lookup",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "hash-table-context-passing-lookup",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
