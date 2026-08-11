// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "valued-verbosity-best-of-all-worlds",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "valued-verbosity-best-of-all-worlds",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
