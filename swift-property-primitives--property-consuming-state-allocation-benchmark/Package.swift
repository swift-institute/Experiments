// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "property-consuming-state-allocation-benchmark",
    platforms: [
        .macOS(.v26),
    ],
    targets: [
        .executableTarget(
            name: "property-consuming-state-allocation-benchmark"
        )
    ],
    swiftLanguageModes: [.v6]
)
