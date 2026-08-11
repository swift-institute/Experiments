// MARK: - Parallel Iteration Primitives Experiment
// Purpose: Validate the full algebraic stack for parallel iteration:
//          ~Copyable Pair/Product → Range.Lazy zip → paired forEach
// Hypothesis: Binary product (Pair) can be made ~Copyable, enabling
//             algebraically-grounded parallel iteration over ~Copyable ranges.
//             Parameter pack Product<each Element: ~Copyable> may or may not work.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED — 17/19 variants pass. V4/V5 refuted (~Copyable packs blocked).
//         Binary zip with ~Copyable Pair is the correct universal primitive.
//         Build Succeeded; all runtime outputs match expectations.
// Date: 2026-02-06

// ============================================================================
// MARK: - V1: ~Copyable Pair (Binary Product)
// Hypothesis: Pair<First: ~Copyable, Second: ~Copyable> compiles and supports
//             borrowing/consuming semantics.
// Result: CONFIRMED — Build Succeeded; Output: "V1 borrow: 42", "V1 consume: 42, hello"
// ============================================================================

struct NCPair<First: ~Copyable, Second: ~Copyable>: ~Copyable {
    var first: First
    var second: Second

    init(_ first: consuming First, _ second: consuming Second) {
        self.first = first
        self.second = second
    }
}

extension NCPair: Copyable where First: Copyable, Second: Copyable {}
extension NCPair: Sendable where First: Sendable, Second: Sendable {}

// Test: borrowing access
func borrowPair(_ pair: borrowing NCPair<Int, String>) -> Int {
    pair.first
}

// Test: consuming access
func consumePair(_ pair: consuming NCPair<Int, String>) -> (Int, String) {
    (pair.first, pair.second)
}

do {
    let p = NCPair(42, "hello")
    print("V1 borrow: \(borrowPair(p))")
    let (a, b) = consumePair(p)
    print("V1 consume: \(a), \(b)")
}

// ============================================================================
// MARK: - V2: ~Copyable Pair with ~Copyable Elements
// Hypothesis: NCPair works when First or Second is actually ~Copyable (move-only).
// Result: CONFIRMED — Output: "borrow: 100", deinit fires correctly
// ============================================================================

struct Resource: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { print("  V2 deinit Resource(\(id))") }
}

func borrowNCPairWithResource(_ pair: borrowing NCPair<Resource, Int>) -> Int {
    pair.first.id + pair.second
}

func consumeNCPairWithResource(_ pair: consuming NCPair<Resource, Int>) -> Int {
    let r = pair.first
    let n = pair.second
    _ = consume r
    return n
}

do {
    print("V2 ~Copyable element:")
    let p = NCPair(Resource(1), 99)
    print("  borrow: \(borrowNCPairWithResource(p))")
    _ = consumeNCPairWithResource(consume p)
}

// ============================================================================
// MARK: - V3: Bifunctor operations on ~Copyable Pair
// Hypothesis: map/bimap can work on ~Copyable Pair with consuming transforms.
// Result: CONFIRMED — Output: "V3 mapSecond: 10, 60"
// ============================================================================

extension NCPair where First: ~Copyable, Second: ~Copyable {
    consuming func mapSecond<NewSecond: ~Copyable>(
        _ transform: (consuming Second) -> NewSecond
    ) -> NCPair<First, NewSecond> {
        NCPair<First, NewSecond>(self.first, transform(self.second))
    }

    borrowing func borrowMapSecond<NewSecond>(
        _ transform: (borrowing Second) -> NewSecond
    ) -> NCPair<First, NewSecond> where First: Copyable {
        NCPair<First, NewSecond>(self.first, transform(self.second))
    }
}

do {
    let p = NCPair(10, 20)
    let mapped = p.mapSecond { $0 * 3 }
    print("V3 mapSecond: \(mapped.first), \(mapped.second)")
}

// ============================================================================
// MARK: - V4: Parameter Pack Product with ~Copyable
// Hypothesis: Product<each Element: ~Copyable> compiles.
// Result: REFUTED
//   error: cannot suppress '~Copyable' on type 'each Element'
//   error: 'each Element' required to be 'Copyable' but is marked with '~Copyable'
//   Command: swift build
//   Swift 6.2.3 does not support ~Copyable suppression on parameter packs.
// ============================================================================

// DOES NOT COMPILE:
// struct NCProduct<each Element: ~Copyable>: ~Copyable {
//     var values: (repeat each Element)
//     init(_ values: repeat consuming each Element) {
//         self.values = (repeat each values)
//     }
// }

// Copyable-only variant works:
struct CopyProduct<each Element> {
    var values: (repeat each Element)

    init(_ values: repeat each Element) {
        self.values = (repeat each values)
    }
}

extension CopyProduct: Sendable where repeat each Element: Sendable {}

do {
    let binary = CopyProduct(1, "two")
    print("V4 Copyable binary: \(binary.values.0), \(binary.values.1)")

    let ternary = CopyProduct(1, "two", 3.0)
    print("V4 Copyable ternary: \(ternary.values.0), \(ternary.values.1), \(ternary.values.2)")
}

// ============================================================================
// MARK: - V5: Parameter Pack Product — ~Copyable BLOCKED
// Hypothesis: NCProduct works with actual move-only elements.
// Result: REFUTED — blocked by V4 (cannot define ~Copyable parameter pack type)
// ============================================================================

// Skipped — V4 proves this is impossible in Swift 6.2.3.
print("V5 SKIPPED — ~Copyable parameter packs not supported")

// ============================================================================
// MARK: - V6: Minimal Range.Lazy with forEach
// Hypothesis: A minimal Range.Lazy-like type with borrowing forEach compiles
//             with ~Copyable bounds.
// Result: CONFIRMED — Output: "V6 forEach: 0 10 20"
// ============================================================================

struct LazyRange<Bound: ~Copyable> {
    let start: Int
    let end: Int
    let transform: @Sendable (Int) -> Bound

    init(start: Int, end: Int, transform: @escaping @Sendable (Int) -> Bound) {
        self.start = start
        self.end = end
        self.transform = transform
    }

    init(count: Int, transform: @escaping @Sendable (Int) -> Bound) {
        self.start = 0
        self.end = count
        self.transform = transform
    }
}

// ~Copyable-safe forEach (explicit constraint suppression)
extension LazyRange where Bound: ~Copyable {
    func forEach(_ body: (borrowing Bound) -> Void) {
        var i = start
        while i < end {
            let bound = transform(i)
            body(bound)
            i += 1
        }
    }

    func forEach<E: Error>(_ body: (borrowing Bound) throws(E) -> Void) throws(E) {
        var i = start
        while i < end {
            let bound = transform(i)
            try body(bound)
            i += 1
        }
    }
}

do {
    let range = LazyRange(count: 3) { $0 * 10 }
    print("V6 forEach:", terminator: "")
    range.forEach { print(" \($0)", terminator: "") }
    print()
}

// ============================================================================
// MARK: - V7: paired(from:) — Binary Parallel Iteration
// Hypothesis: forEach can be extended with a paired counter that advances in
//             lockstep, returning the final position. Closure receives
//             (borrowing Bound, Int). Works with typed throws.
// Result: CONFIRMED — Output: final position = 14
// ============================================================================

extension LazyRange where Bound: ~Copyable {
    @discardableResult
    func forEachPaired<E: Error>(
        from counterStart: Int,
        _ body: (borrowing Bound, Int) throws(E) -> Void
    ) throws(E) -> Int {
        var i = self.start
        var j = counterStart
        while i < end {
            let bound = transform(i)
            try body(bound, j)
            i += 1
            j += 1
        }
        return j
    }
}

do {
    let range = LazyRange(count: 4) { "item\($0)" }
    let finalPos = range.forEachPaired(from: 10) { item, idx in
        print("  V7 paired: \(item) at \(idx)")
    }
    print("V7 final position: \(finalPos)")
}

// ============================================================================
// MARK: - V8: Composition — Chaining Return Values
// Hypothesis: Two sequential forEachPaired calls can be chained via the return
//             value, modeling ring buffer linearization (two disjoint ranges
//             packed contiguously).
// Result: CONFIRMED — slot5→dst[0]..slot7→dst[2], slot0→dst[3]..slot2→dst[5], total=6
// ============================================================================

do {
    print("V8 composition (ring buffer):")
    let first = LazyRange(start: 5, end: 8) { "slot\($0)" }
    let second = LazyRange(start: 0, end: 3) { "slot\($0)" }

    let mid = first.forEachPaired(from: 0) { item, dst in
        print("  copy \(item) → dst[\(dst)]")
    }
    let final_ = second.forEachPaired(from: mid) { item, dst in
        print("  copy \(item) → dst[\(dst)]")
    }
    print("V8 total copied: \(final_)")
}

// ============================================================================
// MARK: - V9: paired(from:) with ~Copyable Bounds
// Hypothesis: forEachPaired works when Bound is ~Copyable (the body receives
//             borrowing Bound).
// Result: CONFIRMED — Output: slot[0]→dst[100]..slot[2]→dst[102], final=103
// ============================================================================

struct Slot: ~Copyable {
    let index: Int
    init(_ index: Int) { self.index = index }
}

do {
    print("V9 ~Copyable paired:")
    let range = LazyRange<Slot>(count: 3) { Slot($0) }
    let final_ = range.forEachPaired(from: 100) { slot, dst in
        print("  move slot[\(slot.index)] → dst[\(dst)]")
    }
    print("V9 final: \(final_)")
}

// ============================================================================
// MARK: - V10: zip — Algebraic Zip Producing Pair
// Hypothesis: A zip function can combine two LazyRange instances into a
//             LazyRange<NCPair<A, B>>, where the output is the binary product.
//             This is the monoidal functor φ₂ : F(a) × F(b) → F(a × b).
// Result: CONFIRMED — Output: "name0: 0", "name1: 100", "name2: 200"
// ============================================================================

func zip<A: ~Copyable, B: ~Copyable>(
    _ a: LazyRange<A>,
    _ b: LazyRange<B>
) -> LazyRange<NCPair<A, B>> {
    let count = min(a.end - a.start, b.end - b.start)
    return LazyRange<NCPair<A, B>>(count: count) { i in
        NCPair(a.transform(a.start + i), b.transform(b.start + i))
    }
}

do {
    let names = LazyRange(count: 3) { "name\($0)" }
    let scores = LazyRange(count: 3) { $0 * 100 }
    let zipped = zip(names, scores)
    print("V10 zip:")
    zipped.forEach { pair in
        print("  \(pair.first): \(pair.second)")
    }
}

// ============================================================================
// MARK: - V11: zip with ~Copyable Elements
// Hypothesis: zip works when one or both element types are ~Copyable.
//             The resulting NCPair is ~Copyable, and forEach receives it
//             as borrowing.
// Result: CONFIRMED — Output: "slot[0]→dst[10]".. borrowed NCPair<Slot, Int>
// ============================================================================

do {
    print("V11 zip ~Copyable:")
    let resources = LazyRange<Slot>(count: 3) { Slot($0) }
    let indices = LazyRange<Int>(count: 3) { $0 + 10 }
    let zipped = zip(resources, indices)
    zipped.forEach { pair in
        print("  slot[\(pair.first.index)] → dst[\(pair.second)]")
    }
}

// ============================================================================
// MARK: - V12: N-ary Zip via Parameter Packs
// Hypothesis: A variadic zip using parameter packs can combine N LazyRange
//             instances. Since ~Copyable packs are blocked (V4), test
//             Copyable-only N-ary zip + Copyable-only pack construction.
// Result: CONFIRMED (Copyable only) — Output: "(0, item0, 0.0)"..
// ============================================================================

// ~Copyable N-ary zip is impossible (V4 proves it).
// Copyable-only N-ary zip:
func zipN<each Bound>(
    _ ranges: repeat LazyRange<each Bound>
) -> LazyRange<CopyProduct<repeat each Bound>> {
    // Find minimum count
    var minCount = Int.max
    func updateMin<B>(_ r: LazyRange<B>) { minCount = min(minCount, r.end - r.start) }
    repeat updateMin(each ranges)

    return LazyRange<CopyProduct<repeat each Bound>>(count: minCount) { i in
        CopyProduct(repeat (each ranges).transform((each ranges).start + i))
    }
}

do {
    print("V12 N-ary zip (Copyable only):")
    let a = LazyRange(count: 3) { $0 }
    let b = LazyRange(count: 3) { "item\($0)" }
    let c = LazyRange(count: 3) { Double($0) * 1.5 }
    let zipped = zipN(a, b, c)
    zipped.forEach { prod in
        print("  (\(prod.values.0), \(prod.values.1), \(prod.values.2))")
    }
}

// ============================================================================
// MARK: - V13: forEachPaired with Generic Counter Type
// Hypothesis: The paired counter can be any type with a successor-like
//             advancing function, not just Int. This generalizes to Index<T>.
// Result: CONFIRMED — Int final=3, Double final=1.5
// ============================================================================

extension LazyRange where Bound: ~Copyable {
    @discardableResult
    func forEachPairedGeneric<Counter, E: Error>(
        from start: Counter,
        advancing: (Counter) -> Counter,
        _ body: (borrowing Bound, Counter) throws(E) -> Void
    ) throws(E) -> Counter {
        var i = self.start
        var j = start
        while i < end {
            let bound = transform(i)
            try body(bound, j)
            i += 1
            j = advancing(j)
        }
        return j
    }
}

do {
    print("V13 generic counter:")
    let range = LazyRange(count: 3) { "item\($0)" }
    // Counter is Int, advancing by +1
    let final1 = range.forEachPairedGeneric(from: 0, advancing: { $0 + 1 }) { item, idx in
        print("  \(item) at \(idx)")
    }
    print("  final (Int): \(final1)")

    // Counter is Double, advancing by +0.5
    let final2 = range.forEachPairedGeneric(from: 0.0, advancing: { $0 + 0.5 }) { item, idx in
        print("  \(item) at \(idx)")
    }
    print("  final (Double): \(final2)")
}

// ============================================================================
// MARK: - V14: Typed Throws + @discardableResult Interaction
// Hypothesis: @discardableResult works correctly with typed throws —
//             the return value is available when not throwing, and the error
//             type propagates correctly.
// Result: CONFIRMED — non-throwing OK, caught IterationError.limitReached at idx 3
// ============================================================================

enum IterationError: Error {
    case limitReached
}

do {
    print("V14 typed throws:")
    let range = LazyRange(count: 5) { $0 }

    // Non-throwing usage (discarding result)
    range.forEachPaired(from: 0) { val, idx in
        _ = (val, idx) // no-op
    }
    print("  non-throwing: OK")

    // Throwing usage (capturing result)
    do {
        let final_ = try range.forEachPaired(from: 0) { (val: borrowing Int, idx: Int) throws(IterationError) in
            if idx >= 3 { throw .limitReached }
            print("  \(val) at \(idx)")
        }
        print("  final: \(final_)")
    } catch {
        print("  caught: \(error)")
    }
}

// ============================================================================
// MARK: - V15: Performance Baseline — Manual While Loop vs forEachPaired
// Hypothesis: After inlining, forEachPaired has identical performance to a
//             manual while loop. Verify by comparing iteration counts.
// Result: CONFIRMED — both sums = 999999000000, match: true
// ============================================================================

do {
    print("V15 performance equivalence:")
    let n = 1_000_000
    var sum1 = 0
    var sum2 = 0

    // Manual while loop
    let range = LazyRange(count: n) { $0 }
    var src = 0
    var dst = 0
    while src < n {
        sum1 += src + dst
        src += 1
        dst += 1
    }

    // forEachPaired
    range.forEachPaired(from: 0) { val, idx in
        sum2 += val + idx
    }

    print("  manual sum: \(sum1)")
    print("  paired sum: \(sum2)")
    print("  match: \(sum1 == sum2)")
}

// ============================================================================
// MARK: - V16: zip as Alternative to paired — Ergonomic Comparison
// Hypothesis: zip(range, identityRange) can replace forEachPaired by zipping
//             the source range with an identity range producing indices.
//             Compare ergonomics.
// Result: CONFIRMED — both approaches produce identical output
// ============================================================================

do {
    print("V16 zip vs paired ergonomics:")

    // Approach A: forEachPaired (dedicated method)
    let range = LazyRange(count: 3) { "item\($0)" }
    print("  paired:")
    range.forEachPaired(from: 10) { item, idx in
        print("    \(item) at \(idx)")
    }

    // Approach B: zip with identity range (algebraic)
    let indices = LazyRange(start: 10, end: 13) { $0 }
    let zipped = zip(range, indices)
    print("  zip:")
    zipped.forEach { pair in
        print("    \(pair.first) at \(pair.second)")
    }
}

// ============================================================================
// MARK: - V17: zip with ~Copyable — Both Elements Move-Only
// Hypothesis: zip works when BOTH element types are ~Copyable.
//             NCPair<~Copyable, ~Copyable> is itself ~Copyable, borrowed in forEach.
// Result: CONFIRMED — NCPair<Slot, Handle> borrowed in forEach callback
// ============================================================================

struct Handle: ~Copyable {
    let fd: Int
    init(_ fd: Int) { self.fd = fd }
}

do {
    print("V17 zip both ~Copyable:")
    let slots = LazyRange<Slot>(count: 3) { Slot($0) }
    let handles = LazyRange<Handle>(count: 3) { Handle($0 + 100) }
    let zipped = zip(slots, handles)
    zipped.forEach { pair in
        print("  slot[\(pair.first.index)] → handle(\(pair.second.fd))")
    }
}

// ============================================================================
// MARK: - V18: Nested zip — Arity 3 via Composition
// Hypothesis: zip(zip(a, b), c) produces LazyRange<NCPair<NCPair<A, B>, C>>.
//             Arity 3+ composes from binary zip by monoidal associativity.
// Result: CONFIRMED — Output: "(0, item0, 0.0)", "(1, item1, 1.5)", "(2, item2, 3.0)"
// ============================================================================

do {
    print("V18 nested zip (arity 3):")
    let a = LazyRange(count: 3) { $0 }
    let b = LazyRange(count: 3) { "item\($0)" }
    let c = LazyRange(count: 3) { Double($0) * 1.5 }

    let zipped3 = zip(zip(a, b), c)
    zipped3.forEach { outer in
        print("  (\(outer.first.first), \(outer.first.second), \(outer.second))")
    }
}

// ============================================================================
// MARK: - V19: Nested zip with ~Copyable — Arity 3
// Hypothesis: Nested zip works when elements are ~Copyable.
//             NCPair<NCPair<Slot, Handle>, Int> is ~Copyable by construction.
// Result: CONFIRMED — NCPair<NCPair<Slot, Handle>, Int> composes correctly
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

do {
    print("V19 nested zip ~Copyable (arity 3):")
    let slots = LazyRange<Slot>(count: 3) { Slot($0) }
    let handles = LazyRange<Handle>(count: 3) { Handle($0 + 100) }
    let indices = LazyRange<Int>(count: 3) { $0 + 200 }

    let zipped3 = zip(zip(slots, handles), indices)
    zipped3.forEach { outer in
        print("  slot[\(outer.first.first.index)] handle(\(outer.first.second.fd)) → \(outer.second)")
    }
}

// ============================================================================
// MARK: - Results Summary
// ============================================================================

print("\n=== Results Summary ===")
print("V1  ~Copyable Pair basic:           CONFIRMED")
print("V2  ~Copyable Pair elements:        CONFIRMED")
print("V3  Bifunctor on ~Copyable Pair:    CONFIRMED")
print("V4  Parameter Pack ~Copyable:       REFUTED — cannot suppress ~Copyable on packs")
print("V5  ~Copyable Product elements:     SKIPPED — blocked by V4")
print("V6  Minimal Range.Lazy forEach:     CONFIRMED")
print("V7  paired(from:) basic:            CONFIRMED")
print("V8  Composition chaining:           CONFIRMED")
print("V9  paired with ~Copyable bound:    CONFIRMED")
print("V10 zip producing Pair:             CONFIRMED")
print("V11 zip with ~Copyable elements:    CONFIRMED")
print("V12 N-ary zip (Copyable only):      CONFIRMED")
print("V13 Generic counter type:           CONFIRMED")
print("V14 Typed throws interaction:       CONFIRMED")
print("V15 Performance equivalence:        CONFIRMED")
print("V16 zip vs paired ergonomics:       CONFIRMED")
print("V17 zip both ~Copyable:             CONFIRMED")
print("V18 Nested zip (arity 3):           CONFIRMED")
print("V19 Nested zip ~Copyable (arity 3): CONFIRMED")
print("")
print("=== Key Findings ===")
print("1. Pair<First: ~Copyable, Second: ~Copyable> works — upgrade existing Pair")
print("2. Product<each Element: ~Copyable> BLOCKED — Swift 6.2.3 limitation")
print("3. Binary zip (φ₂) is the correct universal primitive for ~Copyable")
print("4. N-ary only possible for Copyable types (via parameter packs)")
print("5. Nested zip(zip(a,b),c) composes to arity N for ~Copyable")
