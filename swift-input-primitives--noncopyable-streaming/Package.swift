// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "noncopyable-streaming",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "noncopyable-streaming")
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    target.swiftSettings = [
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("NonescapableTypes"),
        .enableExperimentalFeature("LifetimeDependence"),
        .strictMemorySafety(),
    ]
}
