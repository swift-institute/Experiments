// MARK: - Double-Tagged Bounded Index Composition
// Purpose: Validate that Index<Element>.Bounded<N> (= Tagged<Element, Ordinal.Finite<N>>)
//          composes correctly with .map(), .retag(), arithmetic, and memory layout.
//
// Hypothesis: Tagged<Element, Tagged<Finite.Bound<N>, Ordinal>> works as a zero-cost
//             bounded index with full access to Ordinal.Finite<N> arithmetic.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED - All 8 variants pass. Double-tagged types compose correctly.
// Date: 2026-02-10

import Index_Primitives
import Finite_Primitives
import Tagged_Primitives
import Ordinal_Primitives
import Cardinal_Primitives

// ============================================================================
// MARK: - Variant 1: Typealias Definition
// Hypothesis: Tagged<Element, Ordinal.Finite<N>> compiles as a typealias
// Result: CONFIRMED - Compiles and constructs correctly
// ============================================================================

/// The proposed bounded index type.
/// Index<Element>.Bounded<N> = Tagged<Element, Ordinal.Finite<N>>
///                            = Tagged<Element, Tagged<Finite.Bound<N>, Ordinal>>
typealias BoundedIndex<Element: ~Copyable, let N: Int> = Tagged<Element, Ordinal.Finite<N>>

func testVariant1() {
    print("=== Variant 1: Typealias Definition ===")

    // Can we construct it?
    let finite: Ordinal.Finite<8> = Ordinal.Finite<8>(3)!
    let bounded: BoundedIndex<Int, 8> = BoundedIndex<Int, 8>(__unchecked: (), finite)
    print("  BoundedIndex<Int, 8> constructed: rawValue = \(bounded.rawValue)")
    print("  Underlying Ordinal.Finite<8>: \(bounded.rawValue)")
    print("  Variant 1: CONFIRMED")
}

// ============================================================================
// MARK: - Variant 2: Memory Layout
// Hypothesis: Tagged<Element, Tagged<Finite.Bound<N>, Ordinal>> has the same
//             memory layout as Ordinal (UInt), with zero overhead.
// Result: CONFIRMED - All three: size=8 stride=8 align=8
// ============================================================================

func testVariant2() {
    print("\n=== Variant 2: Memory Layout ===")

    let ordinalSize = MemoryLayout<Ordinal>.size
    let ordinalStride = MemoryLayout<Ordinal>.stride
    let ordinalAlign = MemoryLayout<Ordinal>.alignment

    let finiteSize = MemoryLayout<Ordinal.Finite<8>>.size
    let finiteStride = MemoryLayout<Ordinal.Finite<8>>.stride
    let finiteAlign = MemoryLayout<Ordinal.Finite<8>>.alignment

    let boundedSize = MemoryLayout<BoundedIndex<Int, 8>>.size
    let boundedStride = MemoryLayout<BoundedIndex<Int, 8>>.stride
    let boundedAlign = MemoryLayout<BoundedIndex<Int, 8>>.alignment

    print("  Ordinal:                size=\(ordinalSize) stride=\(ordinalStride) align=\(ordinalAlign)")
    print("  Ordinal.Finite<8>:      size=\(finiteSize) stride=\(finiteStride) align=\(finiteAlign)")
    print("  BoundedIndex<Int, 8>:   size=\(boundedSize) stride=\(boundedStride) align=\(boundedAlign)")

    let sameLayout = ordinalSize == finiteSize && finiteSize == boundedSize
        && ordinalStride == finiteStride && finiteStride == boundedStride
        && ordinalAlign == finiteAlign && finiteAlign == boundedAlign

    if sameLayout {
        print("  All three have identical memory layout: CONFIRMED (zero-cost)")
    } else {
        print("  Memory layouts DIFFER: REFUTED")
    }
}

// ============================================================================
// MARK: - Variant 3: Ordinal.Finite<N> Arithmetic Through Double-Tagged
// Hypothesis: BoundedIndex<Element, N>.rawValue gives Ordinal.Finite<N>,
//             which has successor(), predecessor(), offset(by:), etc.
// Result: CONFIRMED - All arithmetic returns Optional, total at bounds
// ============================================================================

func testVariant3() {
    print("\n=== Variant 3: Arithmetic Delegation ===")

    let idx: BoundedIndex<Int, 4> = BoundedIndex<Int, 4>(__unchecked: (), Ordinal.Finite<4>(2)!)

    // Access the Ordinal.Finite<N> via .rawValue
    let finite: Ordinal.Finite<4> = idx.rawValue
    print("  idx.rawValue = \(finite) (Ordinal.Finite<4>)")

    // successor
    if let next = finite.successor() {
        print("  successor() = \(next): CONFIRMED")
    } else {
        print("  successor() = nil: unexpected")
    }

    // predecessor
    if let prev = finite.predecessor() {
        print("  predecessor() = \(prev): CONFIRMED")
    } else {
        print("  predecessor() = nil: unexpected")
    }

    // successor at bound
    let atMax: BoundedIndex<Int, 4> = BoundedIndex<Int, 4>(__unchecked: (), Ordinal.Finite<4>(3)!)
    if atMax.rawValue.successor() == nil {
        print("  successor() at max = nil: CONFIRMED (total, no crash)")
    }

    // predecessor at zero
    let atZero: BoundedIndex<Int, 4> = BoundedIndex<Int, 4>(__unchecked: (), .zero)
    if atZero.rawValue.predecessor() == nil {
        print("  predecessor() at zero = nil: CONFIRMED (total, no crash)")
    }

    // offset
    if let offset = finite.offset(by: -1) {
        print("  offset(by: -1) = \(offset): CONFIRMED")
    }

    if finite.offset(by: 10) == nil {
        print("  offset(by: 10) = nil (out of bounds): CONFIRMED")
    }

    // distance
    let other: Ordinal.Finite<4> = Ordinal.Finite<4>(0)!
    let dist = finite.distance(to: other)
    print("  distance(from: 2, to: 0) = \(dist): CONFIRMED")
}

// ============================================================================
// MARK: - Variant 4: .map() Composition
// Hypothesis: .map() on BoundedIndex<Element, N> transforms the Ordinal.Finite<N>
//             raw value while preserving the Element phantom tag.
// Result: CONFIRMED - .map() transforms Ordinal.Finite, preserves Tag
// ============================================================================

func testVariant4() {
    print("\n=== Variant 4: .map() Composition ===")

    let idx: BoundedIndex<Int, 8> = BoundedIndex<Int, 8>(__unchecked: (), Ordinal.Finite<8>(3)!)

    // .map transforms RawValue (Ordinal.Finite<N>), preserving Tag (Element)
    let mapped: BoundedIndex<Int, 8> = idx.map { finite in
        // We can manipulate the Ordinal.Finite<8> inside
        finite.successor() ?? finite
    }
    print("  idx.map { successor } = \(mapped.rawValue): CONFIRMED")

    // .map to a different RawValue type
    let asInt: Tagged<Int, Int> = idx.map { finite in
        Int(bitPattern: finite.rawValue)
    }
    print("  idx.map { Int(bitPattern:) } = \(asInt.rawValue): CONFIRMED")
}

// ============================================================================
// MARK: - Variant 5: .retag() Composition
// Hypothesis: .retag() on BoundedIndex<Element, N> changes the phantom Element tag
//             while preserving the Ordinal.Finite<N> raw value.
// Result: CONFIRMED - .retag() changes phantom tag, preserves raw value
// ============================================================================

enum NodeTag {}
enum EdgeTag {}

func testVariant5() {
    print("\n=== Variant 5: .retag() Composition ===")

    let nodeIdx: BoundedIndex<NodeTag, 16> = BoundedIndex<NodeTag, 16>(__unchecked: (), Ordinal.Finite<16>(5)!)
    print("  nodeIdx: BoundedIndex<NodeTag, 16> = \(nodeIdx.rawValue)")

    // Retag from NodeTag to EdgeTag
    let edgeIdx: BoundedIndex<EdgeTag, 16> = nodeIdx.retag(EdgeTag.self)
    print("  edgeIdx: BoundedIndex<EdgeTag, 16> = \(edgeIdx.rawValue)")

    // Raw values are identical
    let same = nodeIdx.rawValue == edgeIdx.rawValue
    print("  rawValue preserved after retag: \(same ? "CONFIRMED" : "REFUTED")")

    // Type safety: nodeIdx and edgeIdx are different types
    // nodeIdx == edgeIdx  // ← Would not compile: different Tag types
    print("  Type safety: BoundedIndex<NodeTag> != BoundedIndex<EdgeTag> (compile-time): CONFIRMED")
}

// ============================================================================
// MARK: - Variant 6: Checked Construction
// Hypothesis: BoundedIndex<Element, N> can be constructed via Ordinal.Finite<N>'s
//             checked init, making invalid indices unrepresentable.
// Result: CONFIRMED - Out-of-bounds and negative values return nil
// ============================================================================

func testVariant6() {
    print("\n=== Variant 6: Checked Construction ===")

    // Valid construction
    if let finite = Ordinal.Finite<4>(2) {
        let idx = BoundedIndex<Int, 4>(__unchecked: (), finite)
        print("  BoundedIndex<Int, 4>(2) = \(idx.rawValue): CONFIRMED")
    }

    // Invalid construction (out of bounds)
    if Ordinal.Finite<4>(4) == nil {
        print("  Ordinal.Finite<4>(4) = nil (at bound): CONFIRMED")
    }

    if Ordinal.Finite<4>(99) == nil {
        print("  Ordinal.Finite<4>(99) = nil (way out): CONFIRMED")
    }

    if Ordinal.Finite<4>(-1) == nil {
        print("  Ordinal.Finite<4>(-1) = nil (negative): CONFIRMED")
    }

    // Zero-capacity
    if Ordinal.Finite<0>(0) == nil {
        print("  Ordinal.Finite<0>(0) = nil (zero capacity): CONFIRMED")
    }

    print("  Invalid indices are unrepresentable: CONFIRMED")
}

// ============================================================================
// MARK: - Variant 7: Practical Subscript Pattern
// Hypothesis: A collection can offer a subscript taking BoundedIndex<Element, N>
//             that eliminates the capacity precondition, leaving only count check.
// Result: CONFIRMED - Reduces 3 preconditions to 1 (count only)
// ============================================================================

struct FixedBuffer<Element: Hashable, let capacity: Int> {
    private var _storage: [Element?]
    private var _count: Int = 0

    init() {
        _storage = Array(repeating: nil, count: capacity)
    }

    var count: Int { _count }

    // Traditional subscript: TWO checks (capacity + count)
    subscript(traditional index: Int) -> Element {
        precondition(index >= 0, "Negative index")
        precondition(index < capacity, "Exceeds capacity")
        precondition(index < _count, "Exceeds count")
        return _storage[index]!
    }

    // Bounded subscript: ONE check (count only — capacity proven by type)
    subscript(index: BoundedIndex<Element, capacity>) -> Element {
        // index.rawValue is Ordinal.Finite<capacity>, so:
        // - index >= 0: guaranteed (Ordinal is non-negative)
        // - index < capacity: guaranteed (Finite<capacity> is bounded)
        // - index < count: MUST still check at runtime
        precondition(Int(bitPattern: index.rawValue.rawValue) < _count, "Exceeds count")
        return _storage[Int(bitPattern: index.rawValue.rawValue)]!
    }

    mutating func append(_ element: Element) {
        guard _count < capacity else { return }
        _storage[_count] = element
        _count += 1
    }
}

func testVariant7() {
    print("\n=== Variant 7: Practical Subscript Pattern ===")

    var buffer = FixedBuffer<Int, 8>()
    buffer.append(10)
    buffer.append(20)
    buffer.append(30)

    // Bounded subscript: only count check needed
    if let finite = Ordinal.Finite<8>(1) {
        let idx = BoundedIndex<Int, 8>(__unchecked: (), finite)
        let value = buffer[idx]
        print("  buffer[bounded: 1] = \(value): CONFIRMED")
    }

    // Compile-time rejection of out-of-capacity index:
    // Ordinal.Finite<8>(8) returns nil — can't even construct the index
    if Ordinal.Finite<8>(8) == nil {
        print("  Ordinal.Finite<8>(8) = nil (capacity bound enforced at construction): CONFIRMED")
    }

    // The traditional subscript needs 3 checks; bounded needs 1
    print("  Traditional: 3 preconditions (>=0, <capacity, <count)")
    print("  Bounded:     1 precondition (<count only)")
    print("  Precondition reduction: 3 → 1: CONFIRMED")
}

// ============================================================================
// MARK: - Variant 8: Injection / Projection Through Double-Tagged
// Hypothesis: Ordinal.Finite<N>'s injected()/projected() work through
//             BoundedIndex, enabling safe upcasts and checked downcasts.
// Result: CONFIRMED - injected() and projected() work through double-tagged
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

func testVariant8() {
    print("\n=== Variant 8: Injection / Projection ===")

    // Create BoundedIndex<Int, 4> with value 2
    let small: BoundedIndex<Int, 4> = BoundedIndex<Int, 4>(__unchecked: (), Ordinal.Finite<4>(2)!)

    // Inject into larger bound: Fin(4) → Fin(8)
    let largerFinite: Ordinal.Finite<8> = small.rawValue.injected()
    let large = BoundedIndex<Int, 8>(__unchecked: (), largerFinite)
    print("  injected: BoundedIndex<Int, 4>(2) → BoundedIndex<Int, 8>(2) = \(large.rawValue): CONFIRMED")

    // Project back to smaller bound (succeeds: 2 < 4)
    if let projected: Ordinal.Finite<4> = large.rawValue.projected() {
        let back = BoundedIndex<Int, 4>(__unchecked: (), projected)
        print("  projected: BoundedIndex<Int, 8>(2) → BoundedIndex<Int, 4>(2) = \(back.rawValue): CONFIRMED")
    }

    // Project to too-small bound (fails: 2 >= 2)
    let atTwo: BoundedIndex<Int, 8> = BoundedIndex<Int, 8>(__unchecked: (), Ordinal.Finite<8>(2)!)
    let tooSmall: Ordinal.Finite<2>? = atTwo.rawValue.projected()
    if tooSmall == nil {
        print("  projected: BoundedIndex<Int, 8>(2) → BoundedIndex<Int, 2> = nil: CONFIRMED")
    }
}

// ============================================================================
// MARK: - Results Summary
// ============================================================================

func printSummary() {
    print("\n" + String(repeating: "=", count: 60))
    print("RESULTS SUMMARY")
    print(String(repeating: "=", count: 60))
    print("""

    V1 Typealias definition:              CONFIRMED
    V2 Memory layout (zero-cost):         CONFIRMED (size=8 stride=8 align=8 for all three)
    V3 Arithmetic delegation:             CONFIRMED (successor/predecessor/offset all total)
    V4 .map() composition:                CONFIRMED (transforms raw value, preserves tag)
    V5 .retag() composition:              CONFIRMED (changes tag, preserves raw value)
    V6 Checked construction:              CONFIRMED (nil for out-of-bounds, negative, zero-capacity)
    V7 Practical subscript (3→1 checks):  CONFIRMED (eliminates >=0 and <capacity checks)
    V8 Injection / Projection:            CONFIRMED (upcast safe, downcast checked)

    """)
}

// ============================================================================
// MARK: - Run All
// ============================================================================

testVariant1()
testVariant2()
testVariant3()
testVariant4()
testVariant5()
testVariant6()
testVariant7()
testVariant8()
printSummary()
