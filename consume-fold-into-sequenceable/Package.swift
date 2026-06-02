// swift-tools-version: 6.3
import PackageDescription

// Build-check (supervisor-directed): can the REAL `Sequenceable` subsume
// `Sequence.Consume.View` for a ~Copyable-Element conformer? Owned move-out
// `next()` + deinit cleanup + an owned-consuming `forEach` terminal (the "small
// ADD"). Verifies axes (ii) owned ~Copyable yield + (iii) early-exit cleanup +
// (iv) call-site, against the real protocols, in DEBUG and RELEASE.
let package = Package(
    name: "consume-fold-into-sequenceable",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-sequence-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-iterator-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-either-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "consume-fold-into-sequenceable",
            dependencies: [
                .product(name: "Sequence Protocol Primitives", package: "swift-sequence-primitives"),
                .product(name: "Sequence ForEach Primitives", package: "swift-sequence-primitives"),
                .product(name: "Iterator Primitive", package: "swift-iterator-primitives"),
                .product(name: "Iterator Protocol", package: "swift-iterator-primitives"),
                .product(name: "Either Primitives", package: "swift-either-primitives"),
            ]
        ),
    ]
)

// Ecosystem-standard Swift settings (faithful to the real institute packages).
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
