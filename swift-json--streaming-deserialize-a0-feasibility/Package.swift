// swift-tools-version: 6.3
//
// Streaming JSON Deserialize — Phase A0 Feasibility Spike.
//
// Verifies three language/toolchain premises for the Option B architecture
// recommended by:
//   swift-institute/Research/streaming-json-deserialize-comparative-analysis.md v1.0.0
//
// Three independent executable targets, one per premise:
//
//   check-token-kind-storage      — RFC_8259.Token.Kind in ~Copyable & ~Escapable
//                                   struct. Exercises the no-payload cases AND
//                                   the .unknown(UInt8) case explicitly, per
//                                   the comparative analysis §4.1 / §5 spike #1
//                                   critique. The Phase A1 Span Parser bug-bypass
//                                   (RFC_8259.Parser.Span.swift:18-28) triggered
//                                   on Optional<Token> (String/Number payload);
//                                   Token.Kind has 11 payload-free cases plus
//                                   case unknown(UInt8) — trivial POD payload,
//                                   but the assumption is empirical, not syntactic.
//
//   check-lifetime-inout-protocol — @_lifetime + inout + typed-throws through
//                                   a protocol method, AND a default-fallback
//                                   probe that times Foo (override) vs Bar
//                                   (default impl that drives stream → tree →
//                                   tree-grain) over 10 000 iterations. This
//                                   is the §4.3 empirical signal informing
//                                   whether the protocol-dispatch chain
//                                   inlines flat (no mitigation needed) or
//                                   carries measurable overhead (Option B's
//                                   §4.3 mitigation paths fire).
//
//   check-contiguous-storage      — Regression check on the existing Tier 4
//                                   finding: withContiguousStorageIfAvailable
//                                   engages for native String (small/long),
//                                   [UInt8] / ContiguousArray<UInt8> /
//                                   ArraySlice<UInt8>, bridged NSString on
//                                   Apple platforms, and does NOT engage on a
//                                   non-contiguous lazy collection. Mirrors
//                                   parse-performance-tier-4-feasibility's
//                                   check-contiguous-storage with explicit
//                                   shape-by-shape disposition.
//
// All three targets print one of GREEN / RED / UNCLEAR as their final line
// per premise, plus structured probe-by-probe output.
//
// Date: 2026-05-14
// Toolchain: Apple Swift 6.3.2 (or later)
// Platform: macOS 26.0 (arm64)

import PackageDescription

let lifetimeSettings: [SwiftSetting] = [
    .enableExperimentalFeature("Lifetimes"),
    .enableExperimentalFeature("LifetimeDependence"),
    .enableUpcomingFeature("LifetimeDependence"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "streaming-deserialize-a0-feasibility",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-ietf/swift-rfc-8259.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "check-token-kind-storage",
            dependencies: [
                .product(name: "RFC 8259", package: "swift-rfc-8259")
            ],
            swiftSettings: lifetimeSettings
        ),
        .executableTarget(
            name: "check-lifetime-inout-protocol",
            swiftSettings: lifetimeSettings
        ),
        .executableTarget(
            name: "check-contiguous-storage",
            swiftSettings: lifetimeSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
