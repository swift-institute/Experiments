// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "noncopyable-level1-investigation",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "noncopyable-level1-investigation", targets: ["noncopyable-level1-investigation"])
    ],
    targets: [
        .executableTarget(
            name: "noncopyable-level1-investigation",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("ValueGenerics"),
            ]
        )
    ]
)
