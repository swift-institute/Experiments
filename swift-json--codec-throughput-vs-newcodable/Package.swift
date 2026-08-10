// swift-tools-version: 6.3
//
// codec-throughput-vs-newcodable
// =================================================================
//
// Benchmark experiment comparing JSON codec paths on twitter.json /
// canada.json / citm_catalog.json payloads.
//
// ## Split-binary architecture (forced by toolchain conflict)
//
// Apple's `experimental/new-codable` branch requires Swift 6.4-dev
// (`SuppressedAssociatedTypesWithDefaults` experimental feature),
// while several institute packages are pre-1.0 and have known
// nightly regressions deferred per their CI's `continue-on-error:
// true` policy:
//   - swift-ownership-primitives `Optional.take()` triggers
//     RegionIsolation
//   - swift-effect-primitives `Effect.Outcome` triggers
//     conflicting-conformance against `Equation.Protocol` /
//     `Hash.Protocol` (stricter SE-0499-era conformance rules)
//   - Likely more downstream.
//
// No single toolchain compiles BOTH cleanly today. So:
//
//   - This experiment measures the INSTITUTE side
//     (JSON.Serializable tree-grain + Foundation baseline) under
//     Swift 6.3.2 stable.
//   - Apple's NewCodable numbers are captured by running Apple's
//     own `Tests/NewCodableBenchmarks` target inside
//     `/Users/coen/Developer/swiftlang/swift-foundation` on the
//     `experimental/new-codable` branch under Swift 6.4-dev nightly
//     (e.g., `swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a`,
//     `TOOLCHAINS=org.swift.64202605121a swift test --filter
//     NewCodableBenchmarks -c release`).
//   - Foundation baseline numbers appear in BOTH binaries — they
//     cross-validate the harness methodology.
//
// Comparison table is stitched manually from the two outputs.
//
// ## Measured paths (this binary)
//
//   1. Foundation.JSONDecoder / JSONEncoder            (baseline)
//   2. Swift Institute JSON.Serializable tree-grain    (JSON.parse + T.deserialize(_:))
//   3. Swift Institute JSON.Serializable event-grain   (T.deserialize(events:))    [TODO]
//
// Mirrors Apple's harness methodology (256 iterations, MINIMUM
// interval reported, MB/s throughput against the payload's raw byte
// count) — Apple's reference at
//   /Users/coen/Developer/swiftlang/swift-foundation/
//     Tests/NewCodableBenchmarks/CodableRevolutionBenchmarks.swift
//
// No external baselines (simdjson, serde, etc.) — replicates Apple's
// "vs. Foundation" framing.
//
// ## Skeleton status
//
// PENDING. The synthetic `Person` schema verifies the harness end-to-end
// on an in-code-generated [Person] payload (no fixture file). Real
// payload schemas — Twitter, Canada, Catalog — are stubs in
// Sources/.../{Twitter,Canada,Catalog}.swift with porting
// instructions.
//
// ## Placement
//
// Per [EXP-022], lives in swift-json/Experiments/ because swift-json
// is the highest-layer institute dep.
//
// ## Invocation
//
//   # Skeleton verification (no fixture needed):
//   cd Experiments/codec-throughput-vs-newcodable
//   swift run -c release codec-throughput-vs-newcodable person
//
//   # After porting schemas + fetching fixtures:
//   ./Scripts/fetch-fixtures.sh
//   swift run -c release codec-throughput-vs-newcodable twitter
//   swift run -c release codec-throughput-vs-newcodable canada
//   swift run -c release codec-throughput-vs-newcodable citm
//   swift run -c release codec-throughput-vs-newcodable all
//
// ## Build-cleanup per [BENCH-002]
//
//   rm -rf .build  &&  swift build -c release
//
// ## Foundation usage
//
// This experiment imports Foundation for the Date.now timing primitive
// and the JSONDecoder/JSONEncoder baseline. swift-json itself remains
// Foundation-free; this experiment is the test-adjacent benchmarking
// carve-out (same as parse-performance-bench).

import PackageDescription

let package = Package(
    name: "codec-throughput-vs-newcodable",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swiftlang/swift-foundation.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "codec-throughput-vs-newcodable",
            dependencies: [
                .product(name: "JSON", package: "swift-json"),
                .product(name: "NewCodable", package: "swift-foundation"),
                .product(name: "FoundationEssentials", package: "swift-foundation"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("BuiltinModule"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        )
    ]
)
