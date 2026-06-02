// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "argv-parser-protocol-spike",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-parser-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-input-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-array-primitives.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "ArgvParserSpike",
            dependencies: [
                .product(name: "Parser Primitives", package: "swift-parser-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Array Dynamic Primitives", package: "swift-array-primitives"),
                .product(name: "Array Primitives Core", package: "swift-array-primitives"),
            ]
        ),
        .testTarget(
            name: "ArgvParserSpikeTests",
            dependencies: ["ArgvParserSpike"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]
}
