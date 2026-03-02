// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "nonsending-blocker-validation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "nonsending-blocker-validation",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
