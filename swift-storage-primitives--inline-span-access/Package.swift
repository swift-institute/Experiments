// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "inline-span-access",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "inline-span-access",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
