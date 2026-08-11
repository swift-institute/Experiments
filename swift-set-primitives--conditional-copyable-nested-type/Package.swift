// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "conditional-copyable-nested-type",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "conditional-copyable-nested-type")
    ]
)
