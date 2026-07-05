// swift-tools-version: 6.3

import PackageDescription

// adt-tower-m11-iteration-0witness ([EXP-003d]) — a fresh compiling re-verification of
// Research/adt-tower.md §2 D9 (M11): tower iteration flows from the column as a
// borrowing `forEach` lending `(borrowing Element)`, 0-witness cross-module, for BOTH
// buffer disciplines over a move-only element — path-deps the REAL upstream columns on
// local mains, exactly as the ratified `adt-tower-worked-example` does ([EXP-020]).
let package = Package(
    name: "adt-tower-m11-iteration-0witness",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-primitives/swift-buffer-primitives"),
        .package(path: "../../../swift-primitives/swift-buffer-linear-primitives"),
        .package(path: "../../../swift-primitives/swift-buffer-ring-primitives"),
        .package(path: "../../../swift-primitives/swift-storage-primitives"),
        .package(path: "../../../swift-primitives/swift-memory-allocation-primitives"),
        .package(path: "../../../swift-primitives/swift-memory-heap-primitives"),
        .package(path: "../../../swift-primitives/swift-index-primitives"),
        .package(path: "../../../swift-primitives/swift-iterator-primitives"),
    ],
    targets: [
        // Cross-module consumer ([EXP-017]): builds a REAL Linear column and a REAL Ring
        // column of move-only `Job`s, then iterates each — (1) count via Linear's multipass
        // `Iterable` path, (2) sum via Linear's bespoke borrowing `forEach`, (3) sum via
        // Ring's bespoke borrowing `forEach`. The witness_method SIL gate runs against this
        // target's `-O` SIL.
        .executableTarget(
            name: "client",
            dependencies: [
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                // Linear: the type + bespoke borrowing `forEach` (singular type module) AND
                // the `Buffer.Linear: Iterable` conformance (plural ops/umbrella module).
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                // Ring: the type + bespoke borrowing `forEach` (singular type module). Ring's
                // multipass `Iterable` was active-pruned (D9), so no plural import is needed.
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring-primitives"),
                .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                // The multipass attachable protocol + its retained @inlinable generic
                // `Iterable.forEach` template (the `public_external` witness_method home).
                .product(name: "Iterable", package: "swift-iterator-primitives"),
            ],
            swiftSettings: [.enableExperimentalFeature("SuppressedAssociatedTypes")]
        ),
    ]
)
