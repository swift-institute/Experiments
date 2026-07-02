// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "adt-tower-worked-example",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-primitives/swift-buffer-primitives"),
        .package(path: "../../../swift-primitives/swift-buffer-linear-primitives"),
        .package(path: "../../../swift-primitives/swift-storage-primitives"),
        .package(path: "../../../swift-primitives/swift-memory-allocation-primitives"),
        .package(path: "../../../swift-primitives/swift-memory-heap-primitives"),
        .package(path: "../../../swift-primitives/swift-memory-small-primitives"),
        .package(path: "../../../swift-primitives/swift-index-primitives"),
        .package(path: "../../../swift-primitives/swift-comparison-primitives"),
    ],
    targets: [
        // The worked example: ONE new ADT (a priority queue) + two allocation
        // variants, against the REAL upstream columns ([EXP-020]).
        .target(
            name: "HeapKit",
            dependencies: [
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Allocator Protocol Primitives", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Small Primitives", package: "swift-memory-small-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
            ],
            swiftSettings: [.enableExperimentalFeature("SuppressedAssociatedTypes")]
        ),
        // Cross-module consumer ([EXP-017]).
        .executableTarget(
            name: "client",
            dependencies: [
                "HeapKit",
                .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
            ],
            swiftSettings: [.enableExperimentalFeature("SuppressedAssociatedTypes")]
        ),
    ]
)
