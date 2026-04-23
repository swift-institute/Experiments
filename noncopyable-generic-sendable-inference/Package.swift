// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "noncopyable-generic-sendable-inference",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "noncopyable-generic-sendable-inference"
        )
    ]
)
