// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "initialization-consistency",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-cyclic-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-bit-vector-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "initialization-consistency",
            dependencies: [
                .product(name: "Storage Primitives", package: "swift-storage-primitives"),
                .product(name: "Cyclic Index Primitives", package: "swift-cyclic-index-primitives"),
                .product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),
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
