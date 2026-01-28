// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ownership-overloading-limitation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "ownership-overloading-limitation")
    ]
)
