// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "tagged-mutable-ambiguity",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "tagged-mutable-ambiguity"
        )
    ]
)
