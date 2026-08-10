// swift-tools-version: 6.3
//
// Tier-4 Feasibility Spike (Phase A0 of parse-performance-architecture.md
// v1.0.0). Two independent compiler-binding feasibility checks for the
// Span<UInt8>-based internal lexer/parser proposed by the architecture
// doc — each is its own executable target with its own header.
//
// Per [EXP-022], this experiment lives at the highest-layer dep
// (swift-json, L3), since it verifies premises for changes that will
// land in swift-rfc-8259 (L2) but is consumed by swift-json's
// downstream surface.
//
// Date: 2026-05-13
// Toolchain: Apple Swift 6.3+
// Platform: macOS 26 (arm64)
//
// Disposition (see source headers for per-check rationale):
//
//   check-contiguous-storage   — CONFIRMED. All 7 String shapes
//                                 (small-string, large ASCII, Unicode,
//                                 Substring, decoded-from-bytes, AND
//                                 bridged NSString in both sizes) hit
//                                 the contiguous-storage fast path on
//                                 macOS 26 arm64. The architecture doc
//                                 had projected bridged NSString as a
//                                 slow-path case; empirically it is not.
//
//   check-span-typed-throws    — CONFIRMED. The cursor shape from the
//                                 architecture doc §4.1 compiles and
//                                 runs cleanly: `~Copyable & ~Escapable`
//                                 struct with `let bytes: Span<UInt8>`,
//                                 `@_lifetime(borrow bytes)` init,
//                                 `mutating` methods with typed throws,
//                                 typed errors caught across an
//                                 `inout Cursor` boundary.
//
// User-confirmed (not exercised here):
//
//   ~Escapable on associated types — CONFIRMED 2026-05-13 via
//                                     .enableExperimentalFeature("SuppressedAssociatedTypes").
//                                     Originally established by
//                                     swift-parser-primitives/Experiments/
//                                     suppressed-escapable-associated-types/
//                                     (CONFIRMED 2026-02-13).
//
// Result: Phase A0 is GREEN. Phase A1 is unblocked.

import PackageDescription

let lifetimeSettings: [SwiftSetting] = [
    .enableExperimentalFeature("Lifetimes"),
    .enableExperimentalFeature("LifetimeDependence"),
    .enableUpcomingFeature("LifetimeDependence"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "parse-performance-tier-4-feasibility",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "check-contiguous-storage",
            swiftSettings: lifetimeSettings
        ),
        .executableTarget(
            name: "check-span-typed-throws",
            swiftSettings: lifetimeSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
