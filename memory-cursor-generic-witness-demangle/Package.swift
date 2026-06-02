// swift-tools-version: 6.3
import PackageDescription

// Diagnoses the confirmed Signal-6 runtime crash in the Wave-1 memory->Sequenceable
// bridge on a GENERIC contiguous conformer:
//
//   failed to demangle witness for associated type 'Iterator' in conformance
//   '…Buffer.Linear.Inline<8>: Sequenceable'
//   → swift_getAssociatedTypeWitnessSlowImpl → Sequenceable.collect()  (Signal 6)
//
// Wave-1 spike (memory-contiguous-sequenceable-bridge-shape) PASSED on a CONCRETE
// [Int] base. This package isolates the concrete→generic gap, to verdict:
//   compiler/runtime codegen bug  vs  Memory.Cursor design issue.
//
// Three targets, built separately:
//   A-institute-bridge-generic  — production shape: a minimal GENERIC
//       Memory.ContiguousProtocol conformer declares Sequenceable (Iterator
//       witness = Memory.Cursor<Self>) and drives .collect(). Reproduces (or not)
//       the Signal-6 demangle.
//   B-handrolled-bare-generic   — VERDICT DISCRIMINATOR: a hand-rolled minimal
//       generic protocol + associated-type + constrained-extension witness
//       returning a generic owned struct, INDEPENDENT of the institute bridge.
//       If this crashes too → compiler/runtime bug. If only A crashes → design issue.
//   C-institute-bridge-concrete — control: concrete conformer through the SAME
//       bridge (anchors the concrete→generic gap; should pass like Wave-1).
//
// READ-ONLY on the bridge packages; only path-deps, no edits. Clean build; first
// clean signal is the result ([EXP-011a]).

// Mirror the institute ecosystem feature set that makes the bridge's associated-type
// suppression (`associatedtype Iterator: ..., ~Copyable, ~Escapable`) legal — the
// hand-rolled discriminator (target B) reconstructs that exact shape, so it needs the
// same SuppressedAssociatedTypes feature. The rest are the ecosystem-standard flags.
let settings: [SwiftSetting] = [
    .enableExperimentalFeature("LifetimeDependence"),
    .enableExperimentalFeature("Lifetimes"),
    .enableExperimentalFeature("SuppressedAssociatedTypes"),
]

let package = Package(
    name: "memory-cursor-generic-witness-demangle",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-memory-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-cursor-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-sequence-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-iterator-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-sequence-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-iterator-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ordinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-cardinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-finite-primitives.git", branch: "main"),
        // TRANSIENT (issue-investigation): the LITERAL buffer-linear, to drive .collect() on the
        // real Buffer.Linear.Inline with the transiently-restored Memory.Cursor Sequenceable bridge.
        .package(url: "https://github.com/swift-primitives/swift-buffer-linear-primitives.git", branch: "main"),
    ],
    targets: [
        // --- A: institute bridge, GENERIC conformer (single-module) ---
        .executableTarget(
            name: "A-institute-bridge-generic",
            dependencies: [
                .product(name: "Memory Contiguous Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Cursor Primitives", package: "swift-memory-cursor-primitives"),
                .product(name: "Memory Sequence Primitives", package: "swift-memory-sequence-primitives"),
                .product(name: "Sequence Protocol Primitives", package: "swift-sequence-primitives"),
                .product(name: "Sequence Hint Primitives", package: "swift-sequence-primitives"),
            ],
            swiftSettings: settings
        ),
        // --- A cross-module: conformance in a LIBRARY, .collect() driven from a separate
        //     EXECUTABLE module — mirrors the production module split (conformer in
        //     swift-buffer-linear-primitives; consumed elsewhere). This is the dimension
        //     swift_getAssociatedTypeWitnessSlowImpl is sensitive to ([EXP-017]/[ISSUE-013]).
        .target(
            name: "AConformerLib",
            dependencies: [
                .product(name: "Memory Contiguous Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Cursor Primitives", package: "swift-memory-cursor-primitives"),
                .product(name: "Memory Sequence Primitives", package: "swift-memory-sequence-primitives"),
                .product(name: "Memory Iterator Primitives", package: "swift-memory-iterator-primitives"),
                .product(name: "Sequence Protocol Primitives", package: "swift-sequence-primitives"),
                .product(name: "Sequence Hint Primitives", package: "swift-sequence-primitives"),
                .product(name: "Iterable", package: "swift-iterator-primitives"),
                .product(name: "Iterator Chunk Primitives", package: "swift-iterator-primitives"),
                .product(name: "Iterator Primitive", package: "swift-iterator-primitives"),
            ],
            swiftSettings: settings
        ),
        .executableTarget(
            name: "A-xmodule-exe",
            dependencies: [
                "AConformerLib",
                .product(name: "Sequence Protocol Primitives", package: "swift-sequence-primitives"),
                .product(name: "Sequence Hint Primitives", package: "swift-sequence-primitives"),
                .product(name: "Iterable", package: "swift-iterator-primitives"),
            ],
            swiftSettings: settings
        ),
        // --- B: hand-rolled bare-generic discriminator (single-module). The cross-module
        //     witness path is covered far more faithfully by A-xmodule's RegionBD
        //     (cross-module bridge-default witness), so no separate B cross-module target. ---
        .executableTarget(
            name: "B-handrolled-bare-generic",
            dependencies: [],
            swiftSettings: settings
        ),
        // --- D: a SYNTHETIC @_rawLayout-backed contiguous conformer (wraps the real
        //     @_rawLayout Storage.Inline primitive), consumed cross-module. Isolates the
        //     @_rawLayout-storage factor — the one structural factor the plain-array Region
        //     conformers lack vs Buffer.Linear.Inline. No buffer-linear (avoids the parallel
        //     migration's Iterable-collision contamination).
        .target(
            name: "D-real-buffer-linear-lib",
            dependencies: [
                .product(name: "Storage Inline Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                .product(name: "Memory Contiguous Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Cursor Primitives", package: "swift-memory-cursor-primitives"),
                .product(name: "Memory Sequence Primitives", package: "swift-memory-sequence-primitives"),
                .product(name: "Memory Iterator Primitives", package: "swift-memory-iterator-primitives"),
                .product(name: "Sequence Protocol Primitives", package: "swift-sequence-primitives"),
                .product(name: "Sequence Hint Primitives", package: "swift-sequence-primitives"),
                .product(name: "Iterable", package: "swift-iterator-primitives"),
                .product(name: "Iterator Chunk Primitives", package: "swift-iterator-primitives"),
                .product(name: "Iterator Primitive", package: "swift-iterator-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Ordinal Primitive", package: "swift-ordinal-primitives"),
                .product(name: "Cardinal Primitive", package: "swift-cardinal-primitives"),
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
            ],
            swiftSettings: settings
        ),
        .executableTarget(
            name: "D-real-buffer-linear-exe",
            dependencies: [
                "D-real-buffer-linear-lib",
                .product(name: "Sequence Protocol Primitives", package: "swift-sequence-primitives"),
                .product(name: "Sequence Hint Primitives", package: "swift-sequence-primitives"),
                .product(name: "Iterable", package: "swift-iterator-primitives"),
            ],
            swiftSettings: settings
        ),
        // --- E: FULL 3-MODULE TOPOLOGY reconstruction (the un-tested factor per EXPERIMENT.md
        //     lines 80-87). Type module (singular analog) / ops-conformance module (plural
        //     analog) / bridge-default witness module (swift-memory-sequence-primitives). PLUS
        //     a doubly-nested value-generic ~Copyable @_rawLayout type + dual @_implements +
        //     cross-module bridge-default Sequenceable witness. The closest reconstruction of
        //     Buffer.Linear.Inline<8>: Sequenceable achievable without buffer-linear.
        .target(
            name: "E-type-module",
            dependencies: [
                .product(name: "Storage Inline Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Ordinal Primitive", package: "swift-ordinal-primitives"),
                .product(name: "Cardinal Primitive", package: "swift-cardinal-primitives"),
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
            ],
            swiftSettings: settings
        ),
        .target(
            name: "E-ops-module",
            dependencies: [
                "E-type-module",
                .product(name: "Storage Inline Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Contiguous Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Cursor Primitives", package: "swift-memory-cursor-primitives"),
                .product(name: "Memory Sequence Primitives", package: "swift-memory-sequence-primitives"),
                .product(name: "Memory Iterator Primitives", package: "swift-memory-iterator-primitives"),
                .product(name: "Sequence Protocol Primitives", package: "swift-sequence-primitives"),
                .product(name: "Iterable", package: "swift-iterator-primitives"),
                .product(name: "Iterator Chunk Primitives", package: "swift-iterator-primitives"),
                .product(name: "Iterator Primitive", package: "swift-iterator-primitives"),
            ],
            swiftSettings: settings
        ),
        .executableTarget(
            name: "E-xmodule-exe",
            dependencies: [
                "E-type-module",
                "E-ops-module",
                .product(name: "Sequence Protocol Primitives", package: "swift-sequence-primitives"),
                .product(name: "Sequence Hint Primitives", package: "swift-sequence-primitives"),
            ],
            swiftSettings: settings
        ),
        // --- F: drive .collect() on the LITERAL Buffer.Linear.Inline (real buffer-linear with the
        //     transiently-restored crashing Memory.Cursor Sequenceable bridge). The only target
        //     that exercises the literal failing type; expected to crash Signal-6.
        .executableTarget(
            name: "F-literal-buffer-linear-exe",
            dependencies: [
                .product(name: "Buffer Linear Inline Primitives", package: "swift-buffer-linear-primitives"),
                .product(name: "Sequence Protocol Primitives", package: "swift-sequence-primitives"),
                .product(name: "Sequence Hint Primitives", package: "swift-sequence-primitives"),
            ],
            swiftSettings: settings
        ),
        // --- C: institute bridge, CONCRETE conformer (control) ---
        .executableTarget(
            name: "C-institute-bridge-concrete",
            dependencies: [
                .product(name: "Memory Contiguous Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Cursor Primitives", package: "swift-memory-cursor-primitives"),
                .product(name: "Memory Sequence Primitives", package: "swift-memory-sequence-primitives"),
                .product(name: "Sequence Protocol Primitives", package: "swift-sequence-primitives"),
                .product(name: "Sequence Hint Primitives", package: "swift-sequence-primitives"),
            ],
            swiftSettings: settings
        ),
    ]
)
