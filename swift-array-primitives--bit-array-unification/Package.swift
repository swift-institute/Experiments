// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "bit-array-unification",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "bit-array-unification"
        )
    ]
)
