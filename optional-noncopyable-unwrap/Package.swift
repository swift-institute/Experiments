// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "optional-noncopyable-unwrap",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "optional-noncopyable-unwrap",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
