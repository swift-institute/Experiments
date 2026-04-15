// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "unsafe-forin-release-crash",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "UnsafeLib",
            swiftSettings: [
                .enableExperimentalFeature("StrictMemorySafety"),
            ]
        ),
        .executableTarget(
            name: "Repro",
            dependencies: ["UnsafeLib"],
            swiftSettings: [
                .enableExperimentalFeature("StrictMemorySafety"),
            ]
        ),
    ]
)
