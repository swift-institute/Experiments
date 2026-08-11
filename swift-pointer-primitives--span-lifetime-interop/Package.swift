// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "span-lifetime-interop",
    platforms: [
        .macOS(.v26),
    ],
    targets: [
        .executableTarget(name: "span-lifetime-interop"),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    target.swiftSettings = [
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety(),
    ]
}
