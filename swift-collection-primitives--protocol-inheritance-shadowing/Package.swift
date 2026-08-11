// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "protocol-inheritance-shadowing",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "protocol-inheritance-shadowing",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
