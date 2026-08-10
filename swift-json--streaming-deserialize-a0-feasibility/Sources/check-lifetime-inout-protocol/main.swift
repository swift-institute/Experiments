// Check #2 — @_lifetime + inout (~Copyable & ~Escapable) + typed throws
//             through a protocol witness, AND a default-fallback timing probe.
//
// Verifies the Phase A0 spike #2 premise from
// swift-institute/Research/streaming-json-deserialize-comparative-analysis.md
// §4.2 + §4.3 + §5.
//
// Two questions wrapped in one target:
//
//  1. Does the compiler accept an `inout EventStream` parameter (where
//     EventStream is ~Copyable & ~Escapable, lifetime-bound via
//     @_lifetime(borrow bytes)) on a protocol method with typed throws?
//     Does the lifetime checker stay happy as the inout flows through
//     a `withUnsafeBufferPointer` closure, into a static method on a
//     conformer struct, and back out?
//
//  2. Does the §4.3 default-fallback path (where the conformer does NOT
//     override `deserialize(events:)` but inherits a protocol-extension
//     default that drives stream → tree → tree-grain dispatch) inline
//     flat under `-c release`? Or does it carry measurable dispatch
//     overhead vs the direct path? The §4.3 mitigation choice depends
//     on this signal.
//
// Disposition:
//   GREEN  — both compile/run AND Bar (default fallback) ≤1.10× Foo (direct)
//   RED    — anything fails to compile OR Bar >1.30× Foo
//   UNCLEAR — in-between (1.10× to 1.30×) or unexpected warning

// MARK: - Typed error (mirrors RFC_8259.Error shape)

enum MockError: Error {
    case unexpectedEnd
    case malformedInput(at: Int)
}

// MARK: - Event stream (mirrors the planned JSON.Span.EventStream shape)
//
// `~Copyable & ~Escapable` per the cursor lifetime contract documented in
// the comparative analysis §4.1. @safe per the strict-memory-safety
// requirement.

@safe
struct MockEventStream: ~Copyable, ~Escapable {
    @usableFromInline
    internal let bytes: Span<UInt8>

    @usableFromInline
    internal var position: Int

    @inlinable
    @_lifetime(borrow bytes)
    init(_ bytes: borrowing Span<UInt8>) {
        self.bytes = copy bytes
        self.position = 0
    }
}

extension MockEventStream {
    /// Mutating method with typed throws — the next() shape in the design.
    @inlinable
    @_lifetime(self: copy self)
    mutating func nextByte() throws(MockError) -> UInt8? {
        guard position < bytes.count else { return nil }
        let byte = bytes[position]
        position &+= 1
        return byte
    }

    /// A second mutating-method shape: skipping bytes — mirrors
    /// EventStream.skipValue() per the design's structural-skip primitive.
    @inlinable
    @_lifetime(self: copy self)
    mutating func skip(_ n: Int) throws(MockError) {
        let target = position &+ n
        guard target <= bytes.count else { throw .unexpectedEnd }
        position = target
    }
}

// MARK: - Tree-grain intermediate (mirrors JSON value for the default path)

struct MockTree {
    var values: [UInt8]
}

// MARK: - The protocol with both event-grain and tree-grain methods
//
// Mirrors the planned JSON.Serializable shape per §4.2:
//
//     extension JSON {
//         public protocol Serializable {
//             static func deserialize(_ json: JSON) throws(JSON.Error) -> Self
//             // NEW — opt-in fast path; default delegates to tree-grain.
//             static func deserialize(events: inout JSON.Span.EventStream)
//                 throws(JSON.Error) -> Self
//         }
//     }

protocol MockSerializable {
    static func deserialize(_ tree: MockTree) throws(MockError) -> Self
    static func deserialize(events: inout MockEventStream) throws(MockError) -> Self
}

// MARK: - Default fallback per §4.3
//
// The default implementation drives the event stream to build a MockTree,
// then dispatches to the tree-grain method. This is the path that pays
// the silent-regression risk per §4.3's expanded treatment:
//
//   New path with default fallback:
//     bytes → EventStream → assemble(events → tree) → deserialize(_: tree) → Self
//
// vs the direct override path:
//
//   bytes → EventStream → deserialize(events:) → Self (bypasses tree)
//
// The default-fallback adds at least one protocol-dispatch boundary
// (the witness for `deserialize(events:)` calling through to the default,
// which then calls back through the witness for `deserialize(_: tree)`).
// Whether this collapses to flat with @inlinable + -O depends on the
// optimizer's behaviour.

extension MockSerializable {
    @inlinable
    static func deserialize(events: inout MockEventStream) throws(MockError) -> Self {
        // Drive the event stream into a MockTree (the "assemble" step).
        var tree = MockTree(values: [])
        tree.values.reserveCapacity(64)
        while let b = try events.nextByte() {
            tree.values.append(b)
        }
        // Dispatch to the tree-grain method via the witness table.
        return try Self.deserialize(tree)
    }
}

// MARK: - Conformer Foo — OVERRIDES deserialize(events:) (the fast path)

struct Foo: MockSerializable {
    let count: Int
    let checksum: UInt64

    @inlinable
    static func deserialize(_ tree: MockTree) throws(MockError) -> Foo {
        // The conformer's tree-grain method, kept for the API surface
        // contract. In the override case, this is unreachable from
        // deserialize(events:) — Foo's event-grain method bypasses it.
        var sum: UInt64 = 0
        for b in tree.values { sum = sum &+ UInt64(b) }
        return Foo(count: tree.values.count, checksum: sum)
    }

    @inlinable
    static func deserialize(events: inout MockEventStream) throws(MockError) -> Foo {
        // The OVERRIDE: drive the event stream directly, no intermediate
        // tree allocation. This is the byte-to-target shape Option B's
        // performance hypothesis depends on.
        var sum: UInt64 = 0
        var count = 0
        while let b = try events.nextByte() {
            sum = sum &+ UInt64(b)
            count &+= 1
        }
        return Foo(count: count, checksum: sum)
    }
}

// MARK: - Conformer Bar — INHERITS the default fallback (no override)
//
// Bar does NOT provide a `deserialize(events:)` — it inherits the
// protocol-extension default, which means every call to
// `Bar.deserialize(events: &stream)` walks through:
//
//   1. Witness-table dispatch into the default impl
//   2. The default loops events → builds MockTree
//   3. Witness-table dispatch into Bar.deserialize(_: MockTree)
//   4. Bar.deserialize reads MockTree to build the result
//
// The default-fallback path under measurement.

struct Bar: MockSerializable {
    let count: Int
    let checksum: UInt64

    @inlinable
    static func deserialize(_ tree: MockTree) throws(MockError) -> Bar {
        // Identical body to Foo.deserialize(_: tree) so the only
        // measured-cost difference between Foo and Bar is the
        // dispatch path, not the work inside the leaf.
        var sum: UInt64 = 0
        for b in tree.values { sum = sum &+ UInt64(b) }
        return Bar(count: tree.values.count, checksum: sum)
    }

    // NOTE: Bar deliberately does NOT override deserialize(events:).
}

// MARK: - Probe A — compilation + correctness through the dispatch chain
//
// Validates that the lifetime checker accepts the full chain:
//   - `let span = buf.span` inside a `withUnsafeBufferPointer` closure
//   - `var stream = MockEventStream(span)` (lifetime borrowed from span)
//   - `try Foo.deserialize(events: &stream)` (inout through protocol witness)
//   - typed throws (MockError) flowing all the way out

print("=== check-lifetime-inout-protocol ===")
print("Verifies @_lifetime + inout(~Copyable & ~Escapable) + typed-throws")
print("through a protocol witness, plus the §4.3 default-fallback timing.")
print("")

// State for [PASS] / [FAIL] tracking. `nonisolated(unsafe)` per the
// spike's single-threaded driver — top-level code runs as the sole
// caller; no concurrent access.
nonisolated(unsafe) var failureCount = 0

func report(_ label: String, _ passed: Bool, detail: String = "") {
    if passed {
        print("  [PASS] \(label)\(detail.isEmpty ? "" : " — \(detail)")")
    } else {
        failureCount &+= 1
        print("  [FAIL] \(label)\(detail.isEmpty ? "" : " — \(detail)")")
    }
}

/// Format a Double to 3 decimals without pulling in Foundation.
/// Returns e.g. "1.234" for 1.2341. Truncates rather than rounds for
/// simplicity; precision is reporting-grade, not measurement-grade.
func format3(_ x: Double) -> String {
    let sign = x < 0 ? "-" : ""
    let v = x < 0 ? -x : x
    let whole = Int(v)
    let frac = Int((v - Double(whole)) * 1000.0 + 0.5)
    // Pad fractional to 3 digits.
    let fracStr: String
    if frac >= 100 { fracStr = "\(frac)" }
    else if frac >= 10 { fracStr = "0\(frac)" }
    else { fracStr = "00\(frac)" }
    return "\(sign)\(whole).\(fracStr)"
}

/// Format a Double to 2 decimals (e.g. "1.23x" via callers appending x).
func format2(_ x: Double) -> String {
    let sign = x < 0 ? "-" : ""
    let v = x < 0 ? -x : x
    let whole = Int(v)
    let frac = Int((v - Double(whole)) * 100.0 + 0.5)
    let fracStr: String
    if frac >= 10 { fracStr = "\(frac)" }
    else { fracStr = "0\(frac)" }
    return "\(sign)\(whole).\(fracStr)"
}

print("--- Probe A: dispatch chain correctness ---")

let smallBytes: [UInt8] = [0x42, 0x99, 0x10, 0xFF, 0x00]

smallBytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) in
    let span: Span<UInt8> = buf.span

    // Foo (override path)
    do {
        var stream = MockEventStream(span)
        do {
            let foo: Foo = try Foo.deserialize(events: &stream)
            let expectedSum: UInt64 = 0x42 + 0x99 + 0x10 + 0xFF + 0x00
            let passed = foo.count == 5 && foo.checksum == expectedSum
            report("Foo (override): bytes → Foo via inout protocol witness", passed,
                   detail: passed
                    ? "count=\(foo.count) sum=\(foo.checksum)"
                    : "count=\(foo.count) sum=\(foo.checksum) expected count=5 sum=\(expectedSum)")
        } catch let e as MockError {
            // Explicit `as MockError` because the surrounding closure
            // (withUnsafeBufferPointer) is generic-rethrows, which widens
            // the inferred catch type to `any Error` without the cast.
            // The TYPED THROW from Foo.deserialize(events:) is still
            // MockError statically — the cast here is recovery-side, not
            // a typed-throws breakage signal.
            switch e {
            case .unexpectedEnd:          report("Foo (override)", false, detail: "unexpectedEnd")
            case .malformedInput(let at): report("Foo (override)", false, detail: "malformedInput at \(at)")
            }
        } catch {
            report("Foo (override)", false, detail: "non-MockError thrown: \(error)")
        }
    }

    // Bar (default fallback path)
    do {
        var stream = MockEventStream(span)
        do {
            let bar: Bar = try Bar.deserialize(events: &stream)
            let expectedSum: UInt64 = 0x42 + 0x99 + 0x10 + 0xFF + 0x00
            let passed = bar.count == 5 && bar.checksum == expectedSum
            report("Bar (default fallback): bytes → tree → Bar via two witness hops", passed,
                   detail: passed
                    ? "count=\(bar.count) sum=\(bar.checksum)"
                    : "count=\(bar.count) sum=\(bar.checksum) expected count=5 sum=\(expectedSum)")
        } catch let e as MockError {
            switch e {
            case .unexpectedEnd:          report("Bar (default fallback)", false, detail: "unexpectedEnd")
            case .malformedInput(let at): report("Bar (default fallback)", false, detail: "malformedInput at \(at)")
            }
        } catch {
            report("Bar (default fallback)", false, detail: "non-MockError thrown: \(error)")
        }
    }
}

// Probe A.2: typed-throws actually propagates the right error type.
// Driving an EventStream past its end via .skip should throw .unexpectedEnd.

print("")
print("--- Probe A.2: typed-throws propagation ---")

smallBytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) in
    let span: Span<UInt8> = buf.span
    var stream = MockEventStream(span)
    do {
        try stream.skip(999)
        report("typed-throws: skip past end raised expected error", false, detail: "no error thrown")
    } catch let e as MockError {
        // The `as MockError` cast is recovery-side because the enclosing
        // closure is generic-rethrows. The typed-throw from skip() is
        // statically MockError per the @_lifetime + typed-throws method
        // declaration; the cast just narrows for switching.
        switch e {
        case .unexpectedEnd:
            report("typed-throws: skip past end raised .unexpectedEnd", true)
        case .malformedInput(let at):
            report("typed-throws: skip past end raised expected error", false,
                   detail: "got .malformedInput(\(at)) instead of .unexpectedEnd")
        }
    } catch {
        report("typed-throws: skip past end raised expected error", false,
               detail: "non-MockError thrown: \(error)")
    }
}

// MARK: - Probe B — Default-fallback timing (§4.3 empirical signal)
//
// 10 000 iterations of each path over a 256-byte input. The two paths
// do identical user-visible work (sum + count); the only difference is
// the dispatch shape. If Bar's path inlines flat, timing should be
// within ~10 % of Foo's. If it carries measurable overhead, Bar will
// be >10 % slower (and possibly >30 %, which fires the §4.3 mitigation
// requirement).

print("")
print("--- Probe B: default-fallback timing (§4.3 empirical signal) ---")

// Build a 256-byte input — large enough that per-byte work dominates
// per-call dispatch noise, small enough that 10 000 iterations finishes
// quickly under -c release. Mirrors the canonical workload's per-element
// shape (tens of bytes per element, many elements).
let largeBytes: [UInt8] = (0..<256).map { UInt8($0 & 0xFF) }

let iterations = 10_000

// Use ContinuousClock for monotonic timing.
let clock = ContinuousClock()

// Helper: build a MockTree from bytes directly, bypassing the event-stream
// machinery entirely. Models today's `init(jsonBytes:)` shape: bytes →
// tree → deserialize(_: tree).
func buildTreeDirect(_ bytes: [UInt8]) -> MockTree {
    var tree = MockTree(values: [])
    tree.values.reserveCapacity(bytes.count)
    for b in bytes { tree.values.append(b) }
    return tree
}

// Warm-up: run each path once before measuring to amortise any first-call
// metadata lookup, dispatch table load, etc.
largeBytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) in
    let span: Span<UInt8> = buf.span
    for _ in 0..<100 {
        var streamFoo = MockEventStream(span)
        _ = try? Foo.deserialize(events: &streamFoo)
        var streamBar = MockEventStream(span)
        _ = try? Bar.deserialize(events: &streamBar)
        let tree = buildTreeDirect(largeBytes)
        _ = try? Bar.deserialize(tree)
    }
}

// Measure Foo (override path).
var fooSum: UInt64 = 0
let fooDuration = clock.measure {
    largeBytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) in
        let span: Span<UInt8> = buf.span
        for _ in 0..<iterations {
            var stream = MockEventStream(span)
            // The do/catch keeps typed-throws honest; the result is summed
            // into a global to prevent the optimizer from elimination.
            do {
                let foo = try Foo.deserialize(events: &stream)
                fooSum = fooSum &+ foo.checksum
            } catch {
                // Should not fire on well-formed input.
            }
        }
    }
}

// Measure Bar (default fallback path — bytes → EventStream →
// assemble-into-tree → deserialize(_: tree)).
var barSum: UInt64 = 0
let barDuration = clock.measure {
    largeBytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) in
        let span: Span<UInt8> = buf.span
        for _ in 0..<iterations {
            var stream = MockEventStream(span)
            do {
                let bar = try Bar.deserialize(events: &stream)
                barSum = barSum &+ bar.checksum
            } catch {
                // Should not fire on well-formed input.
            }
        }
    }
}

// Measure "today" — direct tree-grain dispatch without the event-stream
// indirection at all. Models the existing JSON.Serializable.init(jsonBytes:)
// path: bytes → JSON.parse → tree → deserialize(_: tree) → Self.
//
// The §4.3 default-fallback regression concern is specifically about:
//   "if a consumer switches `init(jsonBytes:)` to
//    `from(eventDecodingJsonBytes:)` without overriding
//    `deserialize(events:)`, do they silently slow down?"
// Compare TODAY (direct tree call) vs Bar (new default fallback).
var todaySum: UInt64 = 0
let todayDuration = clock.measure {
    for _ in 0..<iterations {
        // Build the tree directly from bytes — no event stream, no
        // protocol-witness round-trip through deserialize(events:).
        let tree = buildTreeDirect(largeBytes)
        do {
            let bar = try Bar.deserialize(tree)
            todaySum = todaySum &+ bar.checksum
        } catch {
            // Should not fire on well-formed input.
        }
    }
}

// Convert to milliseconds for reporting.
let fooMs = Double(fooDuration.components.attoseconds) / 1e15
    + Double(fooDuration.components.seconds) * 1e3
let barMs = Double(barDuration.components.attoseconds) / 1e15
    + Double(barDuration.components.seconds) * 1e3
let todayMs = Double(todayDuration.components.attoseconds) / 1e15
    + Double(todayDuration.components.seconds) * 1e3

// Two ratios for §4.3 interpretation:
//   - barVsFoo: how much the default path costs vs the override path.
//                Characterises the wedge consumers gain by overriding.
//   - barVsToday: how much the new default path regresses vs today's
//                  tree path. THIS is the §4.3 silent-regression signal.
let barVsFoo = barMs / fooMs
let barVsToday = barMs / todayMs

print("  iterations:               \(iterations)")
print("  bytes per iteration:      \(largeBytes.count)")
print("  Foo (override) total:     \(format3(fooMs)) ms  (new fast path: bytes → events → Foo)")
print("  Bar (fallback) total:     \(format3(barMs)) ms  (new default: bytes → events → tree → Bar)")
print("  Today (direct tree) total: \(format3(todayMs)) ms  (status quo: bytes → tree → Bar)")
print("  ratio Bar / Foo:          \(format3(barVsFoo))x  (wedge consumers gain by overriding)")
print("  ratio Bar / Today:        \(format3(barVsToday))x  (§4.3 silent-regression vs status quo)")
print("  checksum: foo=\(fooSum) bar=\(barSum) today=\(todaySum)")

// Correctness cross-check: per-iteration each path computes the same
// checksum, so the cumulative sums should be equal. Independent of
// timing — if these diverge, the dispatch chain is broken.
let checksumsMatch = fooSum == barSum && barSum == todaySum
report("checksum equality: Foo / Bar / Today produce identical per-iter results",
       checksumsMatch,
       detail: "fooSum=\(fooSum) barSum=\(barSum) todaySum=\(todaySum)")

// ------------------------------------------------------------
// Disposition
// ------------------------------------------------------------
print("")
print("--- Disposition ---")
print("")

if failureCount > 0 {
    print("PREMISE 2: RED")
    print("  One or more correctness checks failed — see [FAIL] lines above.")
    print("  The protocol-dispatch chain (@_lifetime + inout(~Copyable &")
    print("  ~Escapable) + typed-throws) does NOT compose cleanly on this")
    print("  toolchain. Option B's protocol shape would need to flip to a")
    print("  closure-based callback per §6 / §7 mitigation paths.")
} else if barVsToday <= 1.10 {
    print("PREMISE 2: GREEN")
    print("  All correctness checks pass. The §4.3 silent-regression signal")
    print("  (Bar / Today = \(format2(barVsToday))x) is within ~10% of the")
    print("  status quo tree path — the protocol-dispatch chain inlines")
    print("  flat across the default-fallback witness. The §4.3")
    print("  implementation-side mitigation (`JSON.assemble` short-circuit)")
    print("  and API-side mitigation (drop the generic entry point) are NOT")
    print("  required for performance reasons; Option B's API-as-designed")
    print("  is viable.")
    print("")
    print("  Separately, the override-vs-default wedge (Bar / Foo =")
    print("  \(format2(barVsFoo))x) characterises the gain consumers get by")
    print("  overriding `deserialize(events:)` rather than inheriting the")
    print("  default — the larger this is, the stronger the incentive to")
    print("  opt in.")
} else if barVsToday <= 1.30 {
    print("PREMISE 2: UNCLEAR")
    print("  Correctness checks pass, but the §4.3 silent-regression signal")
    print("  (Bar / Today = \(format2(barVsToday))x) falls between 1.10x and 1.30x.")
    print("  The default-fallback path adds measurable but bounded overhead")
    print("  vs the status quo tree path. Phase A1 measurement gate should")
    print("  treat the §4.3 mitigations as conditional pending the bench")
    print("  harness's `codable-lookup-event-grain` mode result on the")
    print("  canonical 86 MB workload — if the gap is real on production")
    print("  shapes, either mitigation lands; if it disappears under")
    print("  Span-Parser short-circuit, neither is needed.")
    print("")
    print("  Override wedge (Bar / Foo): \(format2(barVsFoo))x.")
} else {
    print("PREMISE 2: RED")
    print("  Correctness checks pass, but the §4.3 silent-regression signal")
    print("  (Bar / Today = \(format2(barVsToday))x) is >1.30x of the status")
    print("  quo tree path. The default-fallback path materially regresses")
    print("  consumers who switch from `init(jsonBytes:)` to")
    print("  `from(eventDecodingJsonBytes:)` without overriding")
    print("  `deserialize(events:)`. One of §4.3's mitigations is")
    print("  REQUIRED at Phase A1:")
    print("    (1) Implementation-side: `JSON.assemble` short-circuits to")
    print("        `RFC_8259.Span.Parser.parse(_:)` when EventStream is at")
    print("        position 0 and unforked. Preserves the API; eliminates")
    print("        the cost. ← Recommended, lower API churn.")
    print("    (2) API-side: drop the generic entry point; require")
    print("        explicit EventStream construction at the call site.")
    print("        Eliminates the failure mode by construction.")
    print("")
    print("  Override wedge (Bar / Foo): \(format2(barVsFoo))x — this is")
    print("  ALSO the size of the speedup opt-in consumers gain by")
    print("  overriding `deserialize(events:)`. Larger ratio = stronger")
    print("  incentive to opt in.")
    print("")
    print("  Caveat: this mock spike's `MockTree` is a flat [UInt8] copy.")
    print("  In real swift-json, BOTH Bar (default fallback) and Today")
    print("  (status quo) would build the full RFC_8259.Value tree —")
    print("  String/Number allocations, heap-backed object/array storage.")
    print("  The status-quo cost rises in real production, narrowing the")
    print("  Bar / Today gap somewhat. The signal IS real (events-then-")
    print("  tree is strictly more work than tree-direct), but the")
    print("  magnitude of the regression measured in production will be")
    print("  smaller than this mock's 4.42x. Phase A1's bench-mode gate")
    print("  (`codable-lookup-event-grain`) settles the production number.")
}
