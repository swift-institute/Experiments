// MARK: - Experiment: Index.Bounded to Eliminate Preconditions
// Purpose: Explore using Index.Bounded directly to eliminate runtime bounds checks
// Hypothesis: Index.Bounded<capacity> subscripts can be precondition-free for fixed-capacity arrays
//
// Toolchain: swift-6.2-RELEASE
// Status: SUPERSEDED 2026-04-30 — Index.Bounded namespace member removed; bounded-index API moved to Tagged<Element, Bounded>; experiment requires re-targeting
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Result: CONFIRMED - Pattern works, implementation recommendations documented
// Date: 2026-01-22

import Index_Primitives

// ============================================================================
// PART 1: Current State Analysis
// ============================================================================

/*
Current Array.Inline has:
  typealias BoundedIndex = Index_Primitives.Index<Element>.Bounded<capacity>
  subscript(index: BoundedIndex) -> Element {
      precondition(index.rawValue < _count.rawValue, "Index exceeds current count")  // STILL HAS PRECONDITION
  }

The precondition exists because:
  - Index.Bounded<capacity> proves: 0 <= index < capacity
  - But we need: 0 <= index < count (where count <= capacity)

Question: Can we design types that eliminate this precondition?
*/

// ============================================================================
// PART 2: Pattern Analysis
// ============================================================================

/*
Pattern A: Separate subscripts for "within capacity" vs "within count"

For FULL arrays (count == capacity):
  - Index.Bounded<capacity> IS sufficient
  - Subscript CAN be precondition-free

For PARTIAL arrays (count < capacity):
  - Index.Bounded<capacity> is NOT sufficient
  - Need additional proof that index < count

Pattern B: Runtime-bounded index with borrowing

The key insight: validation must happen during a borrow of the collection
to prevent mutation between validation and access.

func withValidIndex<R>(
    _ index: Index<Element>,
    body: (Index.Bounded<capacity>) throws -> R
) rethrows -> R?

Inside body:
  - Index is proven valid for current count
  - Collection is borrowed (immutable)
  - Subscript access is safe without precondition

Pattern C: Count-parameterized bounded index (not possible in Swift)

Index.Bounded<count> where count is runtime value - NOT expressible in Swift's type system
Value generics require compile-time constants
*/

// ============================================================================
// PART 3: Demonstration with Index.Bounded
// ============================================================================

// Simulated Array.Inline to demonstrate patterns (simplified for Copyable)
struct SimulatedInline<Element, let capacity: Int> {
    var _count: Int = 0
    var _storage: [Element?]

    init() {
        _storage = Array(repeating: nil, count: capacity)
    }

    var count: Int { _count }
    var isFull: Bool { _count == capacity }

    // SUBSCRIPT 1: Bounded by capacity, requires count check (current behavior)
    subscript(index: Index<Element>.Bounded<capacity>) -> Element {
        get {
            precondition(index.rawValue < _count, "Index exceeds current count")
            return _storage[index.rawValue]!
        }
        set {
            precondition(index.rawValue < _count, "Index exceeds current count")
            _storage[index.rawValue] = newValue
        }
    }

    // SUBSCRIPT 2: Bounded by capacity, NO PRECONDITION - only safe when full
    // This is the key innovation: precondition-free access for full arrays
    subscript(uncheckedFull index: Index<Element>.Bounded<capacity>) -> Element {
        get {
            // SAFETY: Caller guarantees array is full, so index < capacity == count
            _storage[index.rawValue]!
        }
        set {
            _storage[index.rawValue] = newValue
        }
    }

    // METHOD: Safe access with closure (borrowing pattern)
    // Returns nil if index out of bounds, otherwise calls body with valid index
    func withValidIndex<R>(
        _ index: Index<Element>,
        body: (Self, Index<Element>.Bounded<capacity>) -> R
    ) -> R? {
        // Validate against current count
        guard index.position.rawValue >= 0, index.position.rawValue < _count else {
            return nil
        }
        // Create bounded index (safe because we validated)
        let bounded = Index<Element>.Bounded<capacity>(__unchecked: (), index.position.rawValue)
        // Body executes while self is borrowed (immutable)
        return body(self, bounded)
    }

    // Append for testing
    mutating func append(_ element: Element) {
        guard _count < capacity else { return }
        _storage[_count] = element
        _count += 1
    }
}

// ============================================================================
// PART 4: Test the Patterns
// ============================================================================

func testPatterns() {
    print("=== Index.Bounded Precondition Elimination Experiment ===\n")

    // Test 1: Bounded index with count check (current behavior)
    print("Test 1: Current behavior (precondition on every access)")
    var array = SimulatedInline<Int, 8>()
    for i in 0..<5 {
        array.append(i * 10)
    }

    let idx: Index<Int>.Bounded<8> = 3
    print("  array[\(idx.rawValue)] = \(array[idx])")  // Has precondition

    // Test 2: Full array, unchecked access
    print("\nTest 2: Full array (no precondition needed)")
    var fullArray = SimulatedInline<Int, 4>()
    for i in 0..<4 {
        fullArray.append(i * 100)
    }
    assert(fullArray.isFull)

    let fullIdx: Index<Int>.Bounded<4> = 2
    print("  fullArray[uncheckedFull: \(fullIdx.rawValue)] = \(fullArray[uncheckedFull: fullIdx])")  // NO precondition!

    // Test 3: withValidIndex closure pattern
    print("\nTest 3: Closure pattern (validates once)")
    let unboundedIndex: Index<Int> = Index(__unchecked: (), position: 2)

    if let result = array.withValidIndex(unboundedIndex, body: { arr, validIdx in
        // Inside here: validIdx is PROVEN valid, arr is borrowed
        arr[uncheckedFull: validIdx]  // Safe, no precondition
    }) {
        print("  Valid access: \(result)")
    }

    // Test 4: Out of bounds returns nil
    print("\nTest 4: Out of bounds handling")
    let outOfBounds: Index<Int> = Index(__unchecked: (), position: 99)

    if array.withValidIndex(outOfBounds, body: { arr, validIdx in
        arr[uncheckedFull: validIdx]
    }) == nil {
        print("  Correctly returned nil for out-of-bounds index")
    }

    // Test 5: Direct use of Index.Bounded (no typealias)
    print("\nTest 5: Direct Index.Bounded usage")
    let directIdx: Index<Int>.Bounded<8> = 1
    print("  Direct Index.Bounded<8>: \(directIdx.rawValue)")
    print("  Access: array[\(directIdx.rawValue)] = \(array[directIdx])")

    print("\n=== Summary ===")
    print("1. Index.Bounded<capacity> alone cannot eliminate count checks")
    print("2. For FULL arrays: unchecked subscript is safe")
    print("3. For PARTIAL arrays: closure pattern moves validation to single point")
    print("4. Use Index.Bounded<N> DIRECTLY - no typealiases")
}

// ============================================================================
// PART 5: Recommendations for Implementation
// ============================================================================

/*
RECOMMENDATIONS FOR swift-array-primitives:

1. Array.Inline<capacity>:
   - REMOVE: typealias BoundedIndex
   - USE DIRECTLY: Index<Element>.Bounded<capacity> in subscript signatures
   - KEEP: subscript(index: Index<Element>.Bounded<capacity>) with precondition
   - ADD: subscript(uncheckedFull index: Index<Element>.Bounded<capacity>) without precondition
   - Document: uncheckedFull is only safe when isFull == true

2. Array.Bounded, Array.Unbounded, Array.Small:
   - Cannot eliminate subscript preconditions (dynamic count)
   - KEEP: Current subscript(index: Index<Element>) with precondition
   - RECOMMEND: Use Span for iteration (validates bounds once)

3. Collection.Indexed protocol:
   - No changes needed
   - Protocol cannot express "precondition-free" subscript

4. Collection.Rotated:
   - Use Index.Bounded for internal offset calculations where applicable

BREAKING CHANGES REQUIRED:
   - Remove BoundedIndex typealias from Array.Inline
   - Update all call sites to use Index<Element>.Bounded<capacity> directly

MINIMAL CONVERSION PATTERN:
   - Index<Element> (unbounded) → Index<Element>.Bounded<N> via .bounded<N>()
   - Index<Element>.Bounded<N> → Index<Element> via .unbounded
   - Both conversions are O(1)
*/

// Run the experiments
testPatterns()
print("\n" + String(repeating: "=", count: 60) + "\n")
demonstrateTotality()
