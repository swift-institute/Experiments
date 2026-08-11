// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "borrowing-read-accessor-test",
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
