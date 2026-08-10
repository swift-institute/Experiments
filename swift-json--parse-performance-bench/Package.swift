// swift-tools-version: 6.3
//
// Parse-performance measurement + verification harness for swift-json.
//
// Tracked alongside the symbol-graph-conformance-oracle experiment.
// Used as the standing benchmark for the Tier-0/1/3/4 parse-performance
// work captured at:
//   - swift-foundations/swift-json/Research/parse-performance.md
//   - swift-foundations/swift-json/Research/parse-performance-architecture.md
//
// Per [EXP-022], the experiment lives at the highest-layer dep
// (swift-json, L3), since it consumes the public `JSON.parse(_:)` API.
//
// ## Modes (selected via the third CLI arg)
//
//   floor     - byte-iterate Data + [UInt8] (memory-bandwidth floor)
//   foundation - Foundation.JSONSerialization.jsonObject (baseline)
//   swift-json-string - JSON.parse(String)
//   swift-json-bytes  - JSON.parse([UInt8])
//   all       - run every wall-clock bench above (default)
//   sanity    - parse + traversal + assertion (proves real work; not noise)
//   equiv     - deep tree-equivalence check across 7 fields vs Foundation
//               (proves identical output structure across both parsers)
//   stats     - MIN/median/p90/mean per-iter across N iters with warmup
//               (Foundation + swift-json bytes path back-to-back).
//               MIN-of-N + warmup is Apple's NewCodable methodology.
//   float-microbench - per-call EL parser vs `Double(_: String)` on real
//               canada float tokens. Bit-equivalence check + per-call
//               ns MIN/median/p90/mean across N iters with warmup.
//               Authoritative empirical test for v1.1.0 canada-anomaly
//               tree-shape claim (parse-performance-canada-anomaly.md).
//   tree-microbench - decomposes the residual canada tree-emit cost
//               into three components: (1) per-Value alloc,
//               (2) intermediate `[RFC_8259.Value].append` growth at
//               canada's actual size distribution, (3) recursive
//               tree teardown via holder = nil. Each component runs
//               with the same warmup + MIN-of-N methodology. Drives
//               the Path A / Path B / array-targeted-fix decision
//               per parse-performance-canada-anomaly.md v1.3.0.
//   lex-microbench - decomposes the residual ~96% canada parse cost
//               that tree-microbench surfaced as not-in-tree-emit.
//               (A) per-byte scanner advance, (B) typed-peek
//               dispatch over every byte, (C) lexNumberValue
//               replay on canada's actual Number positions.
//
// ## Invocation
//
//   swift run -c release parse-performance-bench <path-to-json> [iters] [mode]
//
// Example, on the committed 86 MB Swift stdlib symbol graph:
//
//   cd Experiments/parse-performance-bench
//   swift run -c release parse-performance-bench \
//       ../symbol-graph-conformance-oracle/Outputs/swift-stdlib/Swift.symbols.json \
//       3 all
//
// ## Foundation usage
//
// The bench imports Foundation for the JSONSerialization baseline + the
// equiv-mode tree comparison. swift-json itself remains Foundation-free
// in production Sources/; this experiment is the test-adjacent
// benchmarking carve-out.

import PackageDescription

let package = Package(
    name: "parse-performance-bench",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swift-primitives/swift-dictionary-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-hash-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ascii-parser-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-lexer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ascii-primitives.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "parse-performance-bench",
            dependencies: [
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Dictionary Ordered Primitives", package: "swift-dictionary-primitives"),
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
                .product(name: "ASCII Decimal Parser Primitives", package: "swift-ascii-parser-primitives"),
                .product(name: "Lexer Primitives", package: "swift-lexer-primitives"),
                .product(name: "ASCII Primitives", package: "swift-ascii-primitives")
            ]
        )
    ]
)
