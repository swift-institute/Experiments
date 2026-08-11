// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "nonescapable-pointer-test",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "Test",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
