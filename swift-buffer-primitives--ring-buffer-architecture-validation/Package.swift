// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ring-buffer-architecture-validation",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-cyclic-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-sequence-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "ring-buffer-architecture-validation",
            dependencies: [
                .product(name: "Storage Primitives", package: "swift-storage-primitives"),
                .product(name: "Cyclic Index Primitives", package: "swift-cyclic-index-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
