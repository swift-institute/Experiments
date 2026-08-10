// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "property-view-value-generics",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "Main", path: "Sources")
    ]
)
