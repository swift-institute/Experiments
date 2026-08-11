// operator-forwarding experiment
//
// Question: What is the best approach for forwarding operators through Tagged phantom types?
//
// Context:
// - Index<E> = Tagged<E, Ordinal>
// - Index<E>.Count = Tagged<E, Cardinal>
// - Ordinal + Cardinal → Ordinal already exists at primitives level
//
// How should Index Primitives expose these operators on phantom-typed wrappers?
//
// Toolchain: swift-6.2-RELEASE
// Result: [PENDING]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-01-28

// =============================================================================
// MARK: - Simulated Primitives (mimicking the real types)
// =============================================================================

/// Simulated Ordinal (position in well-ordering)
struct Ordinal: Hashable, Comparable, Sendable {
    let rawValue: UInt
    init(_ value: UInt) { self.rawValue = value }
    static var zero: Self { .init(0) }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Simulated Cardinal (count/quantity)
struct Cardinal: Hashable, Comparable, Sendable {
    let rawValue: UInt
    init(_ value: UInt) { self.rawValue = value }
    static var zero: Self { .init(0) }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

// =============================================================================
// MARK: - Ordinal/Cardinal Operators (at "primitives" level)
// =============================================================================

/// Ordinal + Cardinal → Ordinal
func + (lhs: Ordinal, rhs: Cardinal) -> Ordinal {
    Ordinal(lhs.rawValue + rhs.rawValue)
}

/// Cardinal + Ordinal → Ordinal (commutative)
func + (lhs: Cardinal, rhs: Ordinal) -> Ordinal {
    Ordinal(lhs.rawValue + rhs.rawValue)
}

/// Ordinal % Cardinal → Ordinal
func % (lhs: Ordinal, rhs: Cardinal) -> Ordinal {
    Ordinal(lhs.rawValue % rhs.rawValue)
}

/// Ordinal < Cardinal
func < (lhs: Ordinal, rhs: Cardinal) -> Bool {
    lhs.rawValue < rhs.rawValue
}

/// Ordinal >= Cardinal
func >= (lhs: Ordinal, rhs: Cardinal) -> Bool {
    lhs.rawValue >= rhs.rawValue
}

// =============================================================================
// MARK: - Tagged (phantom type wrapper)
// =============================================================================

struct Tagged<Tag, RawValue> {
    var rawValue: RawValue

    init(_ rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

extension Tagged: Equatable where RawValue: Equatable {}
extension Tagged: Hashable where RawValue: Hashable {}
extension Tagged: Sendable where RawValue: Sendable {}

extension Tagged: Comparable where RawValue: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// =============================================================================
// MARK: - Index Primitives (phantom-typed wrappers)
// =============================================================================

typealias Index<E> = Tagged<E, Ordinal>

extension Tagged where RawValue == Ordinal {
    typealias Count = Tagged<Tag, Cardinal>
}

// =============================================================================
// MARK: - THE KEY QUESTION: How to forward operators?
// =============================================================================

// OPTION 1: Thin wrapper that delegates (RECOMMENDED)
// Each operator is ~3 lines, implementation is a single delegation

func + <E>(lhs: Index<E>, rhs: Index<E>.Count) -> Index<E> {
    Index<E>(lhs.rawValue + rhs.rawValue)  // Calls Ordinal + Cardinal
}

func + <E>(lhs: Index<E>.Count, rhs: Index<E>) -> Index<E> {
    Index<E>(lhs.rawValue + rhs.rawValue)  // Calls Cardinal + Ordinal
}

func % <E>(lhs: Index<E>, rhs: Index<E>.Count) -> Index<E> {
    Index<E>(lhs.rawValue % rhs.rawValue)  // Calls Ordinal % Cardinal
}

func < <E>(lhs: Index<E>, rhs: Index<E>.Count) -> Bool {
    lhs.rawValue < rhs.rawValue  // Calls Ordinal < Cardinal
}

func >= <E>(lhs: Index<E>, rhs: Index<E>.Count) -> Bool {
    lhs.rawValue >= rhs.rawValue  // Calls Ordinal >= Cardinal
}

// =============================================================================
// MARK: - Test
// =============================================================================

enum TestTag {}

func test() {
    print("=== Operator Forwarding Test ===\n")

    let index: Index<TestTag> = Tagged(Ordinal(5))
    let count: Index<TestTag>.Count = Tagged(Cardinal(3))

    // Test: Index + Count
    let sum = index + count
    print("Index(5) + Count(3) = Index(\(sum.rawValue.rawValue))")
    assert(sum.rawValue.rawValue == 8)

    // Test: Count + Index (commutative)
    let sum2 = count + index
    print("Count(3) + Index(5) = Index(\(sum2.rawValue.rawValue))")
    assert(sum2.rawValue.rawValue == 8)

    // Test: Index % Count
    let mod = index % count
    print("Index(5) % Count(3) = Index(\(mod.rawValue.rawValue))")
    assert(mod.rawValue.rawValue == 2)

    // Test: Index < Count
    let lt = index < count
    print("Index(5) < Count(3) = \(lt)")
    assert(lt == false)

    // Test: Index >= Count
    let gte = index >= count
    print("Index(5) >= Count(3) = \(gte)")
    assert(gte == true)

    // Type safety: different tags don't mix
    enum OtherTag {}
    let otherCount: Index<OtherTag>.Count = Tagged(Cardinal(10))
    // let invalid = index + otherCount  // ERROR: Cannot convert Index<OtherTag>.Count to Index<TestTag>.Count

    print("\n=== All tests passed ===")
}

// =============================================================================
// MARK: - Analysis
// =============================================================================

func printAnalysis() {
    print("""

    =============================================================================
    ANALYSIS: Operator Forwarding for Tagged Types
    =============================================================================

    FINDING: The simplest approach is thin wrapper free functions.

    PATTERN:
    ```swift
    // At Ordinal Primitives level:
    func + (lhs: Ordinal, rhs: Cardinal) -> Ordinal { ... }

    // At Index Primitives level:
    func + <E>(lhs: Index<E>, rhs: Index<E>.Count) -> Index<E> {
        Index<E>(lhs.rawValue + rhs.rawValue)  // Delegates to Ordinal + Cardinal
    }
    ```

    BENEFITS:
    1. Mathematical operations live at the correct layer (Ordinal/Cardinal/Affine)
    2. Index Primitives just provides phantom-type safety
    3. Each wrapper is 3 lines (signature + one-line body)
    4. Clear delegation - implementation is obvious

    ALTERNATIVES REJECTED:

    1. Protocol-based forwarding (too complex)
       - Requires protocol machinery for associated types
       - Type inference becomes problematic
       - More code, not less

    2. Static operators on enum (doesn't work)
       - Swift requires operators to take the enclosing type as argument
       - Can't define `static func +` on an enum for unrelated types

    3. Automatic forwarding via Tagged (not possible)
       - Tagged can't know about Ordinal + Cardinal
       - Would require each primitives package to extend Tagged

    RECOMMENDED PATTERN:

    1. Define ALL mathematical operations at the lowest level:
       - Ordinal + Cardinal in Ordinal Primitives
       - Ordinal % Cardinal in Ordinal Primitives
       - Ordinal + Vector in Affine Primitives
       - Vector + Vector in Affine Primitives
       - etc.

    2. In Index Primitives, define thin wrappers:
       - Each wrapper delegates to the underlying operation
       - Wrappers enforce phantom type matching
       - ~24 operators total, each 3 lines

    =============================================================================
    """)
}

// =============================================================================
// MARK: - Main
// =============================================================================

test()
printAnalysis()
