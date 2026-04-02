// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "se0461-concurrent-body-sensitivity",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "se0461-concurrent-body-sensitivity",
            swiftSettings: [
                .enableExperimentalFeature("NonisolatedNonsendingByDefault")
            ]
        )
    ]
)
