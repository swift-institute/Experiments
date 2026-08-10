// swift-tools-version: 6.2
import PackageDescription

// MARK: - noncopyable-value-spike
//
// Purpose: feasibility validation for ~Copyable RFC_8259.Value cascade
// (Path B of the canada-perf next-arc decision space).
//
// Hypothesis: a ~Copyable Value enum (Null/Bool/Number/String/Array/Object)
// can be constructed/inspected without compiler defects under Swift 6.3+,
// composes with Memory.Arena for tree storage, and structurally avoids the
// refcount-per-extract trap that killed value-tree-redesign-v2.md's L1.
//
// Scope: SANDBOX ONLY. Does not modify production swift-rfc-8259 source.
//
// Status: 2026-05-20 spike (Path B feasibility).

let package = Package(
    name: "noncopyable-value-spike",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-memory-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "noncopyable-value-spike",
            dependencies: [
                .product(name: "Memory Arena Primitives", package: "swift-memory-primitives"),
            ]
        )
    ]
)
