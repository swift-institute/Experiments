// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "foreign-region-tower-instantiation",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-memory-primitives"),
        .package(path: "../../../swift-memory-heap-primitives"),
        .package(path: "../../../swift-memory-allocation-primitives"),
        .package(path: "../../../swift-storage-primitives"),
        .package(path: "../../../swift-index-primitives"),
        .package(path: "../../../swift-buffer-primitives"),
        .package(path: "../../../swift-span-primitives"),
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "foreign-region-tower-instantiation",
            dependencies: [
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Allocation Primitives", package: "swift-memory-allocation-primitives"),
                .product(name: "Store Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Primitives", package: "swift-storage-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Buffer Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Ring Bounded Primitives", package: "swift-buffer-ring-primitives"),
            ]
        ),
        // V5 lives in its own target so it can carry the ecosystem settings loop
        // (.strictMemorySafety() + feature set) without disturbing the settings-free
        // V1-V4 target; second-target shape per [EXP-017].
        .executableTarget(
            name: "foreign-region-sending",
            dependencies: [
                .product(name: "Span Primitives", package: "swift-span-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
            ],
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
    ]
)
