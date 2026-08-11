// swift-tools-version: 6.3
import PackageDescription

// Experiment: collection-index-escapable-lifetime
// See Sources/collection-index-escapable-lifetime/main.swift for the consolidated
// hypothesis + result header. Four variant targets, built individually:
//
//   ProtocolV2                          — @_lifetime(copy i)      (EXPECT compiles)
//   V1BorrowSelf                        — @_lifetime(borrow self) (EXPECT fails: formIndex escape)
//   V4CopyableIndex                     — Index: ... & ~Copyable  (EXPECT fails: subscript noncopyable param)
//   collection-index-escapable-lifetime — cross-module consumer of ProtocolV2 (EXPECT compiles + runs)

let package = Package(
    name: "collection-index-escapable-lifetime",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-comparison-primitives.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "ProtocolV2",
            dependencies: [.product(name: "Comparison Primitives", package: "swift-comparison-primitives")]
        ),
        .target(
            name: "V1BorrowSelf",
            dependencies: [.product(name: "Comparison Primitives", package: "swift-comparison-primitives")]
        ),
        .target(
            name: "V4CopyableIndex",
            dependencies: [.product(name: "Comparison Primitives", package: "swift-comparison-primitives")]
        ),
        .executableTarget(
            name: "collection-index-escapable-lifetime",
            dependencies: [
                "ProtocolV2",
                .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

// Apply the EXACT swift-collection-primitives ecosystem swiftSettings to every
// target, so the experiment compiles identically to the production package.
// The decisive flags for this experiment: SuppressedAssociatedTypes (enables
// `associatedtype Index: ~Escapable`), LifetimeDependence + Lifetimes (@_lifetime).
for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]
}
