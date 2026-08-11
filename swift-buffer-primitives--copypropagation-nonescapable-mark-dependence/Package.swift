// swift-tools-version: 6.2
import PackageDescription

let settings: [SwiftSetting] = [
    .enableExperimentalFeature("Lifetimes"),
]

let package = Package(
    name: "copypropagation-nonescapable-mark-dependence",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "Core", swiftSettings: settings),
        .target(name: "Middle", dependencies: ["Core"], swiftSettings: settings),
        .executableTarget(name: "Consumer", dependencies: ["Core", "Middle"], swiftSettings: settings),
    ],
    swiftLanguageModes: [.v6]
)
