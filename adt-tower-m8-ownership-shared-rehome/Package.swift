// swift-tools-version: 6.3
import PackageDescription

// [EXP-003d] — adt-tower-m8-ownership-shared-rehome
//
// Re-verifies the M8 (W1.8) MECHANISM from Research/adt-tower.md §D4.5: the CoW column
// re-homed as a generic struct nested in the REAL `Ownership` namespace via a CROSS-PACKAGE
// extension (`extension Ownership { public struct Rehomed<…> }`), wrapping the real
// `Ownership.Box` ([MEM-SAFE-028] drain-box), against the real column stack.
//
// Path-deps mirror swift-shared-primitives' own dependency set (the direct heap-linear column
// the CoW column wraps), plus swift-ownership-primitives for the `Ownership` namespace + box.
let package = Package(
    name: "adt-tower-m8-ownership-shared-rehome",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-primitives/swift-ownership-primitives"),
        .package(path: "../../../swift-primitives/swift-buffer-primitives"),
        .package(path: "../../../swift-primitives/swift-buffer-linear-primitives"),
        .package(path: "../../../swift-primitives/swift-storage-primitives"),
        .package(path: "../../../swift-primitives/swift-memory-allocation-primitives"),
        .package(path: "../../../swift-primitives/swift-memory-heap-primitives"),
        .package(path: "../../../swift-primitives/swift-index-primitives"),
    ],
    targets: [
        // The re-homed CoW column: `extension Ownership { public struct Rehomed<Element, B> }`.
        .target(
            name: "RehomeKit",
            dependencies: [
                .product(name: "Ownership Primitive", package: "swift-ownership-primitives"),
                .product(name: "Ownership Box Primitives", package: "swift-ownership-primitives"),
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Allocator Protocol Primitives", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),
        // Cross-module consumer ([EXP-017]) — exercises H1 runtime CoW semantics.
        .executableTarget(
            name: "adt-tower-m8-ownership-shared-rehome",
            dependencies: [
                "RehomeKit",
                .product(name: "Ownership Primitive", package: "swift-ownership-primitives"),
                .product(name: "Ownership Box Primitives", package: "swift-ownership-primitives"),
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Allocator Protocol Primitives", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),
    ]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]
}
