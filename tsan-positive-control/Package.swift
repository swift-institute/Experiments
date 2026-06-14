// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "tsan-positive-control",
    platforms: [.macOS(.v26)],
    targets: [
        .testTarget(name: "PositiveControlTests")
    ]
)
