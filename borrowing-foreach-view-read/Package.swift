// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "borrowing-foreach-view-read",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "borrowing-foreach-view-read",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
