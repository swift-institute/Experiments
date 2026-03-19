// swift-tools-version: 6.2
import PackageDescription

let settings: [SwiftSetting] = [
    .enableExperimentalFeature("Lifetimes"),
]

let package = Package(
    name: "with-closure-to-property-migration",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "Primitives",
            swiftSettings: settings
        ),
        .target(
            name: "Foundations",
            dependencies: ["Primitives"],
            swiftSettings: settings
        ),
        .executableTarget(
            name: "Consumer",
            dependencies: ["Primitives", "Foundations"],
            swiftSettings: settings
        ),
    ]
)
