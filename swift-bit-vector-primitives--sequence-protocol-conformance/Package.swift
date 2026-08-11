// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "sequence-protocol-conformance",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../"),
        .package(url: "https://github.com/swift-primitives/swift-sequence-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "sequence-protocol-conformance",
            dependencies: [
                .product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
