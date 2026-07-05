// swift-tools-version: 6.3
import PackageDescription

// adt-tower-m7-concretize-count
//
// Fresh compiling re-verification of the M7 seam amendment
// (Research/adt-tower.md §4.2 [DS-025]/[DS-026]): DELETE `associatedtype Count`
// from `Buffer.Protocol` (`__BufferProtocol`); vend concrete
// `count: Index<Element>.Count`; unconstrained `isEmpty` default (`count == .zero`).
//
// Manifest style mirrors Experiments/adt-tower-worked-example: path-deps to the
// REAL atomic-type packages; SuppressedAssociatedTypes for `Element: ~Copyable`.
//
// SeamKit additionally enables InternalImportsByDefault + MemberImportVisibility
// to FAITHFULLY test the M7 dep-surface claim: the concretized seam target should
// need NO direct import of Carrier_Protocol / Cardinal_Primitive — `.zero`/`==`
// resolve via Index_Primitives' `@_exported` re-exports alone.

let package = Package(
    name: "adt-tower-m7-concretize-count",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-primitives/swift-index-primitives"),
        .package(path: "../../../swift-primitives/swift-bit-index-primitives"),
    ],
    targets: [
        // The CONCRETIZED replica seam. Depends ONLY on Index Primitives — the
        // dep-surface claim under test. Strict-import flags make the test faithful.
        .target(
            name: "SeamKit",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        // Six conformers, modeled on the production witness shapes. Separate module
        // → the executable→Witnesses→SeamKit chain gives a genuine cross-module
        // conformance + generic-dispatch boundary ([EXP-017]).
        .target(
            name: "Witnesses",
            dependencies: [
                "SeamKit",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Bit Index Primitives", package: "swift-bit-index-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        ),
        // Cross-module consumer ([EXP-017]): exercises count/isEmpty through a
        // generic function over the seam with `Element: ~Copyable` suppression.
        .executableTarget(
            name: "adt-tower-m7-concretize-count",
            dependencies: [
                "SeamKit",
                "Witnesses",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        ),
    ]
)
