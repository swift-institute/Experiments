// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "protocol-default-accessor",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "protocol-default-accessor",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
