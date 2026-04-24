// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "checkpoint-protocol-test",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "checkpoint-protocol-test")
    ]
)
