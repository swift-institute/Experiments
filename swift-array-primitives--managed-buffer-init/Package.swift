// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "managed-buffer-init",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "main")
    ]
)
