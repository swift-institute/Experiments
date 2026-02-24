// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "protocol-inside-generic-namespace",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "protocol-inside-generic-namespace",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
