// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "relax-trivial-self-default",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "relax-trivial-self-default",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
