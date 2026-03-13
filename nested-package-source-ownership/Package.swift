// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "nested-package-source-ownership",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(name: "Lib", targets: ["Lib"]),
    ],
    targets: [
        .target(
            name: "Lib",
            path: "Sources/Lib"
        ),
        .testTarget(
            name: "Unit Tests",
            dependencies: ["Lib"],
            path: "Tests/Unit Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
