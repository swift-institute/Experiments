// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "span-utf8-property",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "span-utf8-property",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
