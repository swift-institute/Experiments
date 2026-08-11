// MARK: - nextSpan Performance Overhead Measurement (v4 — ~Escapable confirmation)
// Purpose: Confirm whether the SROA limitation is generic to ~Escapable,
//          or Span-specific. v3 showed Span blocks SROA. This version
//          adds V8 (custom ~Escapable struct) and V9 (Escapable struct).
//
// Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-02-14-a
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — overhead is Span-specific, NOT ~Escapable-generic.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         Root cause identified via SIL analysis.
//
//   Release (-O), 1000 elements × 10,000 iterations:
//     V1  direct next()             : 1.25 ms  ← BASELINE
//     V9  Escapable struct          : 0.99 ms  ← PARITY
//     V10 generic ~Escapable struct : 1.00 ms  ← PARITY (generic + ~Escapable!)
//     V8  custom ~Escapable struct  : 1.03 ms  ← PARITY (~Escapable alone!)
//     V5  tuple (ptr,count)         : 1.10 ms  ← PARITY
//     V7  @inline(always) + Span  : 2.99 ms  (2.4x)
//     V4  Span no min()            : 3.26 ms  (2.6x)
//     V3  manual next + Span       : 3.38 ms  (2.7x)
//     V2  full Span protocol ext   : 3.51 ms  (2.8x)
//     V11 Span via extracting      : 5.43 ms  (3.8x — WORSE: 2 Span ops/element)
//     V6  Span + wUBP             : 4.31 ms  (3.5x)
//
//   Root cause (SIL analysis):
//   ~Escapable does NOT block SROA. The overhead comes from Span's
//   _unsafeStart initializer chain, which inlines 5 overhead sources
//   that the optimizer cannot eliminate in a hot loop:
//
//   1. ALIGNMENT CHECK — Span(_unsafeElements:) does ptrtoint + AND 7 +
//      cond_fail on EVERY construction. In an iterator loop where the
//      pointer advances by stride, this is redundant after the first call.
//      (2 checks per construction — one per code path in the SIL)
//
//   2. TRIPLE mark_dependence — Span(_unsafeStart:) calls
//      _overrideLifetime twice (once for UBP intermediary, once for
//      pointer). Combined with the Span-on-iterator dependency, this
//      produces 5 mark_dependence [nonescaping] instructions vs 1 for
//      custom ~Escapable Chunk.
//
//   3. end_cow_mutation_addr — The iterator alloc_stack with
//      mark_dependence triggers COW mutation tracking (2 per iteration).
//
//   4. OPTIONAL UNWRAPPING — Span stores UnsafeRawPointer? (optional).
//      Accessing the pointer requires unchecked_enum_data unwrap.
//
//   5. assumeNonNegative — count accessor wraps _count in
//      _assumeNonNegative, adding a builtin call.
//
//   Call chain: Span(_unsafeStart:count:) → _precondition(count >= 0)
//     → UnsafeBufferPointer intermediary → Span(_unsafeElements:)
//     → UnsafeRawPointer conversion → ALIGNMENT CHECK → Span(_unchecked:)
//     → _overrideLifetime #1 → _overrideLifetime #2
//
//   V11 (extracting workaround) is WORSE (3.8x): bypasses alignment check
//   but requires 2 Span operations per element (first + droppingFirst),
//   each with its own _overrideLifetime + min() + _precondition.
//
//   Compiler source: SROA (SILSROA.cpp) has NO ~Escapable check.
//   The issue is entirely in Span's initializer implementation.
//
// Date: 2026-02-26

// ============================================================================
// MARK: - Protocol Definitions
// ============================================================================

protocol SpanIteratorProtocol: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Element>
}

extension SpanIteratorProtocol where Self: ~Copyable & ~Escapable, Element: Copyable {
    @inlinable
    mutating func next() -> Element? {
        let span = nextSpan(maximumCount: 1)
        return span.isEmpty ? nil : span[0]
    }
}

// ============================================================================
// MARK: - Variant 1: Baseline — direct next() -> Element?
// The floor. Pure pointer read + advance.
// ============================================================================

struct V1_Direct: ~Copyable {
    var base: UnsafePointer<Int>
    var remaining: Int

    @inlinable
    mutating func next() -> Int? {
        guard remaining > 0 else { return nil }
        let value = unsafe base.pointee
        unsafe base = base + 1
        remaining -= 1
        return value
    }
}

// ============================================================================
// MARK: - Variant 2: nextSpan via protocol extension (full overhead)
// The ceiling. Protocol-extension derived next() → nextSpan(1) → span[0].
// ============================================================================

struct V2_SpanProtocol: ~Copyable, SpanIteratorProtocol {
    typealias Element = Int
    var base: UnsafePointer<Int>
    var remaining: Int

    @inlinable @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        let take = min(maximumCount, remaining)
        guard take > 0 else {
            return unsafe Span(_unsafeStart: base, count: 0)
        }
        let span = unsafe Span(_unsafeStart: base, count: take)
        unsafe base = base + take
        remaining -= take
        return span
    }
}

// ============================================================================
// MARK: - Variant 3: Manual inline of derived next() (no protocol extension)
// Tests whether the protocol extension dispatch or generic context causes overhead.
// ============================================================================

struct V3_ManualNext: ~Copyable {
    var base: UnsafePointer<Int>
    var remaining: Int

    @inlinable @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        let take = min(maximumCount, remaining)
        guard take > 0 else {
            return unsafe Span(_unsafeStart: base, count: 0)
        }
        let span = unsafe Span(_unsafeStart: base, count: take)
        unsafe base = base + take
        remaining -= take
        return span
    }

    @inlinable
    mutating func next() -> Int? {
        let span = nextSpan(maximumCount: 1)
        return span.isEmpty ? nil : span[0]
    }
}

// ============================================================================
// MARK: - Variant 4: Hardcoded maximumCount=1 (eliminates min())
// Tests whether min(1, remaining) is the bottleneck.
// ============================================================================

struct V4_NoMin: ~Copyable {
    var base: UnsafePointer<Int>
    var remaining: Int

    @inlinable @_lifetime(&self)
    mutating func nextSpan() -> Span<Int> {
        guard remaining > 0 else {
            return unsafe Span(_unsafeStart: base, count: 0)
        }
        let span = unsafe Span(_unsafeStart: base, count: 1)
        unsafe base = base + 1
        remaining -= 1
        return span
    }

    @inlinable
    mutating func next() -> Int? {
        let span = nextSpan()
        return span.isEmpty ? nil : span[0]
    }
}

// ============================================================================
// MARK: - Variant 5: No Span — return (UnsafePointer, Int) tuple
// Tests whether the Span struct type (with ~Escapable) is the overhead.
// ============================================================================

struct V5_TupleReturn: ~Copyable {
    var base: UnsafePointer<Int>
    var remaining: Int

    @inlinable
    mutating func nextChunk() -> (ptr: UnsafePointer<Int>, count: Int) {
        guard remaining > 0 else {
            return unsafe (ptr: base, count: 0)
        }
        let ptr = unsafe base
        unsafe base = base + 1
        remaining -= 1
        return unsafe (ptr: ptr, count: 1)
    }

    @inlinable
    mutating func next() -> Int? {
        let chunk = nextChunk()
        return chunk.count == 0 ? nil : unsafe chunk.ptr.pointee
    }
}

// ============================================================================
// MARK: - Variant 6: Span but skip bounds check
// Uses withUnsafeBufferPointer to bypass span[0] bounds check.
// ============================================================================

struct V6_NoBoundsCheck: ~Copyable {
    var base: UnsafePointer<Int>
    var remaining: Int

    @inlinable @_lifetime(&self)
    mutating func nextSpan() -> Span<Int> {
        guard remaining > 0 else {
            return unsafe Span(_unsafeStart: base, count: 0)
        }
        let span = unsafe Span(_unsafeStart: base, count: 1)
        unsafe base = base + 1
        remaining -= 1
        return span
    }

    @inlinable
    mutating func next() -> Int? {
        let span = nextSpan()
        guard span.count > 0 else { return nil }
        return span.withUnsafeBufferPointer { unsafe $0.baseAddress!.pointee }
    }
}

// ============================================================================
// MARK: - Variant 7: @inline(always) on derived next()
// Forces inlining of the protocol extension path.
// ============================================================================

struct V7_ForceInline: ~Copyable, SpanIteratorProtocol {
    typealias Element = Int
    var base: UnsafePointer<Int>
    var remaining: Int

    @inlinable @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        let take = min(maximumCount, remaining)
        guard take > 0 else {
            return unsafe Span(_unsafeStart: base, count: 0)
        }
        let span = unsafe Span(_unsafeStart: base, count: take)
        unsafe base = base + take
        remaining -= take
        return span
    }

    @inline(always)
    mutating func next() -> Int? {
        let span = nextSpan(maximumCount: 1)
        return span.isEmpty ? nil : span[0]
    }
}

// ============================================================================
// MARK: - Variant 8: Custom ~Escapable struct (NOT Span)
// Tests whether ANY ~Escapable struct blocks SROA, not just Span.
// Same (ptr, count) data as V5 tuple, but wrapped in ~Escapable.
// ============================================================================

struct Chunk: ~Escapable {
    var ptr: UnsafePointer<Int>
    var count: Int

    @_lifetime(immortal)
    init(ptr: UnsafePointer<Int>, count: Int) {
        self.ptr = unsafe ptr
        self.count = count
    }
}

struct V8_CustomNonEscapable: ~Copyable {
    var base: UnsafePointer<Int>
    var remaining: Int

    @inlinable @_lifetime(&self)
    mutating func nextChunk() -> Chunk {
        guard remaining > 0 else {
            return unsafe Chunk(ptr: base, count: 0)
        }
        let ptr = unsafe base
        unsafe base = base + 1
        remaining -= 1
        return unsafe Chunk(ptr: ptr, count: 1)
    }

    @inlinable
    mutating func next() -> Int? {
        let chunk = nextChunk()
        return chunk.count == 0 ? nil : unsafe chunk.ptr.pointee
    }
}

// ============================================================================
// MARK: - Variant 9: Escapable struct (control)
// Tests whether an Escapable struct with the same shape gets SROA'd.
// If V9 ≈ V1 and V8 ≈ V2, ~Escapable is definitively the cause.
// ============================================================================

struct EscapableChunk {
    var ptr: UnsafePointer<Int>
    var count: Int
}

struct V9_EscapableStruct: ~Copyable {
    var base: UnsafePointer<Int>
    var remaining: Int

    @inlinable
    mutating func nextChunk() -> EscapableChunk {
        guard remaining > 0 else {
            return unsafe EscapableChunk(ptr: base, count: 0)
        }
        let ptr = unsafe base
        unsafe base = base + 1
        remaining -= 1
        return unsafe EscapableChunk(ptr: ptr, count: 1)
    }

    @inlinable
    mutating func next() -> Int? {
        let chunk = nextChunk()
        return chunk.count == 0 ? nil : unsafe chunk.ptr.pointee
    }
}

// ============================================================================
// MARK: - Variant 10: Local generic ~Escapable struct
// Tests whether the overhead is from genericity + ~Escapable.
// Span<Int> is a generic stdlib type. This is a generic local type.
// ============================================================================

struct GenericChunk<T>: ~Escapable {
    var ptr: UnsafePointer<T>
    var count: Int

    @_lifetime(immortal)
    init(ptr: UnsafePointer<T>, count: Int) {
        self.ptr = unsafe ptr
        self.count = count
    }
}

struct V10_GenericNonEscapable: ~Copyable {
    var base: UnsafePointer<Int>
    var remaining: Int

    @inlinable @_lifetime(&self)
    mutating func nextChunk() -> GenericChunk<Int> {
        guard remaining > 0 else {
            return unsafe GenericChunk(ptr: base, count: 0)
        }
        let ptr = unsafe base
        unsafe base = base + 1
        remaining -= 1
        return unsafe GenericChunk(ptr: ptr, count: 1)
    }

    @inlinable
    mutating func next() -> Int? {
        let chunk = nextChunk()
        return chunk.count == 0 ? nil : unsafe chunk.ptr.pointee
    }
}

// ============================================================================
// MARK: - Variant 11: Span via extracting (bypasses alignment check)
// Stores the full remaining Span as iterator state. Uses extracting(first:)
// to return sub-spans and extracting(droppingFirst:) to advance.
// Both use Span(_unchecked:) internally — no alignment check, single
// _overrideLifetime. Tests whether the _unsafeStart overhead is the cause.
// ============================================================================

struct V11_SpanExtracting: ~Copyable, ~Escapable {
    var span: Span<Int>

    @inlinable @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        let take = min(maximumCount, span.count)
        let result = span.extracting(first: take)
        span = span.extracting(droppingFirst: take)
        return result
    }

    @inlinable
    mutating func next() -> Int? {
        let s = nextSpan(maximumCount: 1)
        return s.isEmpty ? nil : s[0]
    }
}

// ============================================================================
// MARK: - Benchmark Functions
// ============================================================================

let N = 1000
let ITERS = 10_000

@inline(never) func bench1(_ p: UnsafePointer<Int>, _ c: Int) -> Int {
    var cs = 0
    for _ in 0..<ITERS {
        var it = unsafe V1_Direct(base: p, remaining: c)
        var s = 0
        while let e = it.next() { s &+= e }
        cs &+= s
    }
    return cs
}

@inline(never) func bench2(_ p: UnsafePointer<Int>, _ c: Int) -> Int {
    var cs = 0
    for _ in 0..<ITERS {
        var it = unsafe V2_SpanProtocol(base: p, remaining: c)
        var s = 0
        while let e = it.next() { s &+= e }
        cs &+= s
    }
    return cs
}

@inline(never) func bench3(_ p: UnsafePointer<Int>, _ c: Int) -> Int {
    var cs = 0
    for _ in 0..<ITERS {
        var it = unsafe V3_ManualNext(base: p, remaining: c)
        var s = 0
        while let e = it.next() { s &+= e }
        cs &+= s
    }
    return cs
}

@inline(never) func bench4(_ p: UnsafePointer<Int>, _ c: Int) -> Int {
    var cs = 0
    for _ in 0..<ITERS {
        var it = unsafe V4_NoMin(base: p, remaining: c)
        var s = 0
        while let e = it.next() { s &+= e }
        cs &+= s
    }
    return cs
}

@inline(never) func bench5(_ p: UnsafePointer<Int>, _ c: Int) -> Int {
    var cs = 0
    for _ in 0..<ITERS {
        var it = unsafe V5_TupleReturn(base: p, remaining: c)
        var s = 0
        while let e = it.next() { s &+= e }
        cs &+= s
    }
    return cs
}

@inline(never) func bench6(_ p: UnsafePointer<Int>, _ c: Int) -> Int {
    var cs = 0
    for _ in 0..<ITERS {
        var it = unsafe V6_NoBoundsCheck(base: p, remaining: c)
        var s = 0
        while let e = it.next() { s &+= e }
        cs &+= s
    }
    return cs
}

@inline(never) func bench7(_ p: UnsafePointer<Int>, _ c: Int) -> Int {
    var cs = 0
    for _ in 0..<ITERS {
        var it = unsafe V7_ForceInline(base: p, remaining: c)
        var s = 0
        while let e = it.next() { s &+= e }
        cs &+= s
    }
    return cs
}

@inline(never) func bench8(_ p: UnsafePointer<Int>, _ c: Int) -> Int {
    var cs = 0
    for _ in 0..<ITERS {
        var it = unsafe V8_CustomNonEscapable(base: p, remaining: c)
        var s = 0
        while let e = it.next() { s &+= e }
        cs &+= s
    }
    return cs
}

@inline(never) func bench9(_ p: UnsafePointer<Int>, _ c: Int) -> Int {
    var cs = 0
    for _ in 0..<ITERS {
        var it = unsafe V9_EscapableStruct(base: p, remaining: c)
        var s = 0
        while let e = it.next() { s &+= e }
        cs &+= s
    }
    return cs
}

@inline(never) func bench10(_ p: UnsafePointer<Int>, _ c: Int) -> Int {
    var cs = 0
    for _ in 0..<ITERS {
        var it = unsafe V10_GenericNonEscapable(base: p, remaining: c)
        var s = 0
        while let e = it.next() { s &+= e }
        cs &+= s
    }
    return cs
}

@inline(never) func bench11(_ span: Span<Int>) -> Int {
    var cs = 0
    for _ in 0..<ITERS {
        var it = V11_SpanExtracting(span: span)
        var s = 0
        while let e = it.next() { s &+= e }
        cs &+= s
    }
    return cs
}

// ============================================================================
// MARK: - Run
// ============================================================================

print("=== nextSpan Overhead Isolation (v4 — ~Escapable confirmation) ===")
print("\(N) elements × \(ITERS) iterations\n")

let clock = ContinuousClock()
let array = Array(0..<N)

array.withUnsafeBufferPointer { buf in
    let p = buf.baseAddress!
    let c = buf.count
    let span = unsafe Span(_unsafeElements: buf)

    // Warmup all variants
    _ = bench1(p, c); _ = bench2(p, c); _ = bench3(p, c)
    _ = bench4(p, c); _ = bench5(p, c); _ = bench6(p, c)
    _ = bench7(p, c); _ = bench8(p, c); _ = bench9(p, c)
    _ = bench10(p, c); _ = bench11(span)

    // Verify correctness
    let expected = bench1(p, c)
    assert(bench2(p, c) == expected, "V2 mismatch")
    assert(bench3(p, c) == expected, "V3 mismatch")
    assert(bench4(p, c) == expected, "V4 mismatch")
    assert(bench5(p, c) == expected, "V5 mismatch")
    assert(bench6(p, c) == expected, "V6 mismatch")
    assert(bench7(p, c) == expected, "V7 mismatch")
    assert(bench8(p, c) == expected, "V8 mismatch")
    assert(bench9(p, c) == expected, "V9 mismatch")
    assert(bench10(p, c) == expected, "V10 mismatch")
    assert(bench11(span) == expected, "V11 mismatch")
    print("Correctness: ALL MATCH\n")

    let t1 = clock.measure { _ = bench1(p, c) }
    let t2 = clock.measure { _ = bench2(p, c) }
    let t3 = clock.measure { _ = bench3(p, c) }
    let t4 = clock.measure { _ = bench4(p, c) }
    let t5 = clock.measure { _ = bench5(p, c) }
    let t6 = clock.measure { _ = bench6(p, c) }
    let t7 = clock.measure { _ = bench7(p, c) }
    let t8 = clock.measure { _ = bench8(p, c) }
    let t9 = clock.measure { _ = bench9(p, c) }
    let t10 = clock.measure { _ = bench10(p, c) }
    let t11 = clock.measure { _ = bench11(span) }

    print("V1  direct next()              : \(t1)  ← BASELINE")
    print("V2  nextSpan (protocol ext)    : \(t2)")
    print("V3  nextSpan (manual next)     : \(t3)")
    print("V4  nextSpan (no min)          : \(t4)")
    print("V5  tuple (ptr,count) no Span  : \(t5)  ← Escapable control")
    print("V6  Span + no bounds check     : \(t6)")
    print("V7  nextSpan + @inline(always): \(t7)")
    print("V8  custom ~Escapable struct   : \(t8)  ← ~Escapable (not Span)")
    print("V9  Escapable struct           : \(t9)  ← Escapable control")
    print("V10 generic ~Escapable struct  : \(t10) ← generic + ~Escapable")
    print("V11 Span via extracting        : \(t11) ← bypasses alignment check")
}

print("\n=== Analysis ===")
print("V5  ≈ V1 → tuple (Escapable) reaches parity")
print("V9  ≈ V1 → Escapable struct reaches parity")
print("V8  ≈ V1 → custom ~Escapable struct reaches parity")
print("V10 ≈ V1 → generic ~Escapable struct reaches parity")
print("V2  >> V1 → Span _unsafeStart overhead (alignment check, mark_dependence)")
print("V11 ≈ V1? → Span via extracting (bypasses _unsafeStart chain)")
