// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "span-to-string-array-conversion",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "span-to-string-array-conversion",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
