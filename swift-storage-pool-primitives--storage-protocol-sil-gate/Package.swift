// swift-tools-version: 6.3
import PackageDescription

// Experiment: storage-protocol-sil-gate
//
// Proves that a `some Storage.`Protocol`` generic specializes to ZERO
// witness-table dispatch through one STRUCT conformer (Storage.Inline) and one
// CLASS conformer (Storage.Pool), in release + cross-module.
//
// Two targets give the cross-module boundary required by [EXP-017]:
//   - StorageProtocolGeneric : declares the generic `sum`/`capacityOf` functions
//   - storage-protocol-sil-gate : main, calls them with concrete Inline + Pool

let package = Package(
    name: "storage-protocol-sil-gate",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        .package(path: "../.."),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
    ],
    targets: [
        // Generic surface — the `some Storage.`Protocol`` consumers under test.
        .target(
            name: "StorageProtocolGeneric",
            dependencies: [
                .product(name: "Storage Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ],
            swiftSettings: experimentSettings
        ),
        // Second module: concrete call sites for the struct + class conformers.
        .executableTarget(
            name: "storage-protocol-sil-gate",
            dependencies: [
                "StorageProtocolGeneric",
                .product(name: "Storage Inline Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Initialization Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Accessor Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Pool Primitives", package: "swift-storage-pool-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ],
            swiftSettings: experimentSettings
        ),
    ]
)

// Mirror the storage-package ecosystem settings so the generic compiles against
// the same feature surface (~Copyable associated types, lifetimes, raw layout).
var experimentSettings: [SwiftSetting] {
    [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("RawLayout"),
    ]
}
