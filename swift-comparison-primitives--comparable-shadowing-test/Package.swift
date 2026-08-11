// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "comparable-shadowing-test",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        // We'll create a mock "comparison-primitives-with-comparable" locally
    ],
    targets: [
        // Test 1: A module that declares a top-level Comparable protocol
        .target(
            name: "ComparableShadow",
            path: "Sources/ComparableShadow"
        ),
        // Test 2: A consumer that imports ComparableShadow
        .executableTarget(
            name: "Consumer",
            dependencies: ["ComparableShadow"],
            path: "Sources/Consumer"
        ),
    ],
    swiftLanguageModes: [.v6]
)
