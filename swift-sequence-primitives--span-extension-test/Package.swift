// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "span-extension-test",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "span-extension-test",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
