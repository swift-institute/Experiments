// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "ComparisonExperiments",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ComparisonExperiments",
            path: "Sources/ComparisonExperiments"
        )
    ],
    swiftLanguageModes: [.v6]
)
