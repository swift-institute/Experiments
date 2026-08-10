# A0 Feasibility — Streaming JSON Deserialize

Phase A0 of the Option B (event-emitting Span parser γ) architecture
recommended in:
- `swift-institute/Research/streaming-json-deserialize-comparative-analysis.md` v1.0.0
- `swift-institute/Research/streaming-json-deserialize-status-quo-and-prior-art.md` v1.0.0

Verifies three language/toolchain premises before any A1 implementation
is authorized. See the Phase A0 section (§5 spike list) of the
comparative-analysis doc for the rationale behind each premise.

Date: 2026-05-14
Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101)
Platform: macOS 26.0 (arm64)
Driver: `swift build -c release` (clean build from empty `.build`)

## Disposition

| Premise | Status | Notes |
|---|---|---|
| 1. Token.Kind storage in ~Copyable & ~Escapable struct (incl `.unknown(UInt8)`) | **GREEN** | 22/22 [PASS] across 12 enum cases, 8 distinct UInt8 payloads, payload-free + payload-carrying coexistence, and 12-way switch dispatch. The §4.1 storage premise holds. |
| 2. @_lifetime + inout + typed-throws through protocol dispatch (incl default-fallback timing) | **RED** | Compilation + correctness PASS (typed throws survives the witness; `inout MockEventStream` flows through `withUnsafeBufferPointer` closure). But §4.3 silent-regression signal Bar/Today = **4.48x** (default-fallback path is 4.48× the status-quo tree path on the mock); Bar/Foo = **32.94x** (override wedge — the speedup opt-in consumers gain). One §4.3 mitigation is REQUIRED at A1. |
| 3. withContiguousStorageIfAvailable engagement (regression check) | **GREEN** | 8/8 [PASS] across the seven previously-engaging shapes (native String small + long, `[UInt8]`, `ContiguousArray<UInt8>`, `ArraySlice<UInt8>`, bridged NSString small + long) and the non-contiguous slow-path canary. No regression vs the Tier 4 finding. |

## Overall

**RED — A1 is unblocked but constrained**: Premises 1 and 3 are
unconditional GREEN; the Option B substrate (Token.Kind storage,
contiguous-storage dispatch) holds on the current toolchain. Premise 2
correctness is GREEN — the language composition (`@_lifetime` + `inout`
on a ~Copyable & ~Escapable cursor + typed throws through a protocol
witness) works as the design assumes. But the §4.3 default-fallback
regression concern is empirically CONFIRMED: a consumer who switches
`init(jsonBytes:)` to `from(eventDecodingJsonBytes:)` without overriding
`deserialize(events:)` would silently slow down. A1 cannot ship the
naïve default-fallback shape from the comparative-analysis sketch
(§4.3); one of the two named §4.3 mitigations is required:

1. **Implementation-side** — `JSON.assemble(from:)` short-circuits to
   `RFC_8259.Span.Parser.parse(_:)` when the EventStream is at position 0
   and unforked. Preserves the API surface; eliminates the cost by
   collapsing the default-fallback path to today's tree path. Recommended
   per §4.3's own framing (lower API churn).
2. **API-side** — drop the generic `from(eventDecodingJsonBytes:)` entry
   point. Require opt-in consumers to construct `JSON.Span.EventStream`
   explicitly at the call site. Eliminates the silent-regression failure
   mode by construction at the cost of one extra line per opt-in call
   site.

A1 selects between (1) and (2) based on the broader API ergonomics
question (the perf gate is decisive — either works); the Phase A2
measurement gate on the bench harness's `codable-lookup-event-grain`
mode is the validation that whichever mitigation lands actually
preserves no-regression for existing consumers.

The 32.94x Bar/Foo wedge is also a positive signal for the architecture:
overriding `deserialize(events:)` produces a large speedup vs the
default, which means opt-in consumers gain decisive performance for
their effort — consistent with Option B's hypothesis that pattern γ
closes the 37% gap to Foundation on partial-shape decode.

## Caveats on the §4.3 measurement

The mock spike's `MockTree` is a flat `[UInt8]` copy; the real
`JSON.assemble(from:)` would build an `RFC_8259.Value` tree with
String/Number allocations and heap-backed object/array storage. BOTH
the Bar (new default) and Today (status quo) paths get more expensive
in production proportionally, so the 4.48x mock ratio is an upper bound
on the structural regression — production will narrow it somewhat but
the wedge is real (events-then-tree is strictly more work than
tree-direct). Phase A1's `codable-lookup-event-grain` bench mode is the
ground truth for the production-scale number.

## Source code

- `Sources/check-token-kind-storage/main.swift` — Premise 1: stores all
  12 `RFC_8259.Token.Kind` cases (11 payload-free + `.unknown(UInt8)`)
  in `Optional<Token.Kind>` fields on a `~Copyable & ~Escapable` struct
  with `@_lifetime(self: copy self)` mutating methods that read/write
  the storage. Exercises store + read + switch-extract + coexistence
  of both payload shapes inside one struct lifetime.
- `Sources/check-lifetime-inout-protocol/main.swift` — Premise 2: minimal
  `MockSerializable` protocol with both event-grain and tree-grain
  methods; `Foo` overrides `deserialize(events:)`, `Bar` inherits the
  protocol-extension default. Three-path timing: Foo (events → Foo
  directly), Bar (events → tree → Bar via default fallback), Today
  (tree → Bar via direct call, no events). 10 000 iterations × 256
  bytes/iter. Reports Bar/Foo (override wedge) and Bar/Today (§4.3
  silent-regression signal).
- `Sources/check-contiguous-storage/main.swift` — Premise 3: 8 probes
  over the shapes RFC_8259.Decode / Option B's planned
  `from(eventDecodingJsonBytes:)` would dispatch. Re-run of the Tier 4
  spike's probes under the current toolchain.

## Re-running

```bash
cd /Users/coen/Developer/swift-foundations/swift-json/Experiments/streaming-deserialize-a0-feasibility
rm -rf .build              # clean build avoids stale artifacts skewing benchmark results
swift build -c release
.build/release/check-token-kind-storage
.build/release/check-lifetime-inout-protocol
.build/release/check-contiguous-storage
```

Build clean (no errors). Premise 2's timing varies run-to-run — repeat
3-5× if the Bar/Today ratio is near a disposition boundary.
