// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "pointer-primitives-feasibility",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "pointer-primitives-feasibility")
    ]
)
