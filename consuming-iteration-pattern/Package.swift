// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "consuming-iteration-pattern",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "consuming-iteration-pattern")
    ]
)
