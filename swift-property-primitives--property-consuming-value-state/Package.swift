// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "property-consuming-value-state",
    platforms: [
        .macOS(.v26),
    ],
    targets: [
        .executableTarget(
            name: "property-consuming-value-state"
        )
    ],
    swiftLanguageModes: [.v6]
)
