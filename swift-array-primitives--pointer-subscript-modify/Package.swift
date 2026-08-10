// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "pointer-subscript-modify",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "main")
    ]
)
