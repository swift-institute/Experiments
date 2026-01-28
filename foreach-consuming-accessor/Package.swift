// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "foreach-consuming-accessor",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "foreach-consuming-accessor")
    ]
)
