// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "mutable-cross-module-ambiguity",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "MemoryLayer"
        ),
        .target(
            name: "PointerLayer",
            dependencies: ["MemoryLayer"]
        ),
        .executableTarget(
            name: "Consumer",
            dependencies: ["MemoryLayer", "PointerLayer"]
        ),
    ]
)
