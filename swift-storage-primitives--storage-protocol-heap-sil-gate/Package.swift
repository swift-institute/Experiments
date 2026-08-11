// swift-tools-version: 6.3
import PackageDescription

// Experiment: storage-protocol-heap-sil-gate
//
// Proves that a `some Storage.`Protocol`` generic specializes to ZERO
// witness-table dispatch through the value-type-façade conformer
// `Storage.Contiguous<Memory.Heap>` (a ~Copyable struct over a private ManagedBuffer-subclass
// allocation), in release + cross-module. Closes [EXP-020] for Heap — the
// wave-3 conformer added by the Opt-A façade restructure.
//
// Mirrors the methodology of the wave-1/2 `storage-protocol-sil-gate`
// experiment in swift-storage-pool-primitives (Inline + Pool), but is placed in
// swift-storage-primitives because that package owns Storage.Contiguous<Memory.Heap> (highest-layer
// dep per [EXP-002c]). The pool experiment is NOT edited.
//
// Two targets give the cross-module boundary required by [EXP-017]:
//   - StorageHeapProtocolGeneric : declares the generic `probe` function
//   - storage-protocol-heap-sil-gate : main, calls it with a concrete Storage<Int>.Contiguous<Memory.Heap<Int>>

let package = Package(
    name: "storage-protocol-heap-sil-gate",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
    ],
    targets: [
        // Generic surface — the `some Storage.`Protocol`` consumer under test.
        .target(
            name: "StorageHeapProtocolGeneric",
            dependencies: [
                .product(name: "Storage Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ],
            swiftSettings: experimentSettings
        ),
        // Second module: concrete call site for the value-type-façade conformer.
        .executableTarget(
            name: "storage-protocol-heap-sil-gate",
            dependencies: [
                "StorageHeapProtocolGeneric",
                .product(name: "Storage Heap Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Initialization Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Accessor Primitives", package: "swift-storage-primitives"),
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
