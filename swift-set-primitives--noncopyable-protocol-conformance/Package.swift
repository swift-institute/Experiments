// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "noncopyable-protocol-conformance",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "Main", path: ".")
    ]
)
