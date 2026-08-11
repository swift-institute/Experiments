// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "set-ordered-consuming-iteration",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "set-ordered-consuming-iteration"
        )
    ]
)
