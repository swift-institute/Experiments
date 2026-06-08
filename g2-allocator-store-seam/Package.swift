// swift-tools-version: 6.3

// ===----------------------------------------------------------------------===//
//
// g2-allocator-store-seam
//
// A DESIGN EXPERIMENT: can the typed `Store.`Protocol`` seam absorb the two
// allocator disciplines — a fixed-slot Pool (free-list) and a bump Arena — or
// must they stay raw `Memory.Allocator.`Protocol``?
//
// NEGATIVE results are the point. See FINDINGS.md.
//
// ===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "g2-allocator-store-seam",
    platforms: [
        .macOS(.v26),
    ],
    dependencies: [
        // The seam under test.
        .package(path: "../../../swift-primitives/swift-store-primitives"),
        // NOTE: swift-storage-primitives is INTENTIONALLY NOT a dependency.
        // Its `Storage Protocol Primitives` target (pulled in transitively by
        // `Storage Contiguous Primitives`) does not compile under the required
        // toolchain org.swift.64202605271a (Swift 6.5-dev): see the upstream-error
        // block in Probe1b.DenseOverSparse.swift. Probe 1b therefore replicates
        // `Storage.Contiguous`'s generic constraint locally (verbatim from the real
        // source) to answer question (d) without depending on the broken target.
        // Raw typed byte backing + address/alignment + the raw allocator baseline.
        .package(path: "../../../swift-primitives/swift-memory-primitives"),
        .package(path: "../../../swift-primitives/swift-memory-allocation-primitives"),
        // Typed slot coordinate.
        .package(path: "../../../swift-primitives/swift-index-primitives"),
        // The element-domain type used by the byte backing.
        .package(path: "../../../swift-primitives/swift-byte-primitives"),
        // Supporting integrations the heap conformer (our reference) pulls in.
        .package(path: "../../../swift-primitives/swift-affine-primitives"),
        .package(path: "../../../swift-primitives/swift-ordinal-primitives"),
        .package(path: "../../../swift-primitives/swift-cardinal-primitives"),
        .package(path: "../../../swift-primitives/swift-standard-library-extensions"),
    ],
    targets: [
        .target(
            name: "G2AllocatorStoreSeam",
            dependencies: [
                .product(name: "Store Protocol Primitives", package: "swift-store-primitives"),
                .product(name: "Store Initialization Primitives", package: "swift-store-primitives"),
                .product(name: "Memory Primitive", package: "swift-memory-primitives"),
                .product(name: "Memory Contiguous Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Address Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Alignment Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Primitives Standard Library Integration", package: "swift-memory-primitives"),
                .product(name: "Memory Allocator Protocol", package: "swift-memory-allocation-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Byte Primitive", package: "swift-byte-primitives"),
                .product(name: "Affine Primitives Standard Library Integration", package: "swift-affine-primitives"),
                .product(name: "Ordinal Primitive", package: "swift-ordinal-primitives"),
                .product(name: "Ordinal Primitives Standard Library Integration", package: "swift-ordinal-primitives"),
                .product(name: "Cardinal Primitive", package: "swift-cardinal-primitives"),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
            ]
        ),
        .executableTarget(
            name: "g2-seam-run",
            dependencies: ["G2AllocatorStoreSeam"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
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

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
