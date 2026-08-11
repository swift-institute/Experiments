// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "nesting-level-test",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "Lib", targets: ["Lib"])
    ],
    targets: [
        .target(name: "Lib")
    ]
)
