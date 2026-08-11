// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "range-lazy-noncopyable",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "range-lazy-noncopyable"
        )
    ]
)
