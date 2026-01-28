// MARK: - Experiment: Array Totality Patterns
// Purpose: Design subscript patterns that achieve totality for Array types
// Builds on: bounded-index-preconditions experiment
//
// Key Insight: The preconditions are in ARRAY subscripts, not in Index_Primitives.
//              This file explores what Array.Inline, Array.Bounded, etc. should do.
//
// Toolchain: swift-6.2-RELEASE
// Result: CONFIRMED - Six totality patterns demonstrated for array subscripts
// Date: 2026-01-22

import Index_Primitives

// ============================================================================
// PART 1: Current State - Where Preconditions Live
// ============================================================================

/*
PRECONDITION AUDIT IN swift-array-primitives:

| File                           | Line | Expression                              |
|--------------------------------|------|-----------------------------------------|
| Array.Index.swift              | 55   | precondition(index < _count)            |
| Array.Index.swift              | 59   | precondition(index < _count)            |
| Array.Index.swift              | 72   | precondition(index < _count)            |
| Array.Index.swift              | 76   | precondition(index < _count)            |
| ... (similar for all array types)                                           |
| Array.Index.swift              | 242  | precondition(index.rawValue < _count)   | <- BoundedIndex subscript
| Array.Index.swift              | 246  | precondition(index.rawValue < _count)   | <- BoundedIndex subscript

The BoundedIndex subscript STILL has preconditions because:
  Index.Bounded<capacity> proves: 0 <= index < capacity
  But we need:                    0 <= index < count (where count <= capacity)
*/

// ============================================================================
// PART 2: Pattern Analysis - Subscript Totality Options
// ============================================================================

/// Simulated Array.Inline to demonstrate totality patterns
struct TotalInlineArray<Element, let capacity: Int>: ~Copyable {
    private var _storage: [Element?]
    private var _count: Int = 0

    init() {
        _storage = Array(repeating: nil, count: capacity)
    }

    var count: Index<Element>.Count {
        Index<Element>.Count(__unchecked: _count)
    }

    var isFull: Bool { _count == capacity }
    var isEmpty: Bool { _count == 0 }

    mutating func append(_ element: Element) throws(AppendError) {
        guard _count < capacity else { throw .full }
        _storage[_count] = element
        _count += 1
    }

    enum AppendError: Error, Equatable { case full }

    // =========================================================================
    // SUBSCRIPT OPTION 1: Keep precondition (current behavior)
    // =========================================================================
    // PRO: Familiar API, matches stdlib Array
    // CON: Non-total, crashes on invalid access

    subscript(preconditioned index: Index<Element>) -> Element {
        get {
            precondition(index < count, "Index out of bounds")
            return _storage[index.position.rawValue]!
        }
    }

    // =========================================================================
    // SUBSCRIPT OPTION 2: Optional return
    // =========================================================================
    // PRO: Total, familiar pattern (.safe[i])
    // CON: Requires unwrapping, harder to chain

    subscript(safe index: Index<Element>) -> Element? {
        guard index < count else { return nil }
        return _storage[index.position.rawValue]
    }

    // =========================================================================
    // SUBSCRIPT OPTION 3: Typed throws
    // =========================================================================
    // PRO: Total, explicit error handling, typed errors
    // CON: Requires try/catch, more verbose

    enum AccessError: Error, Equatable {
        case indexOutOfBounds(index: Int, count: Int)
    }

    func element(at index: Index<Element>) throws(AccessError) -> Element {
        guard index < count else {
            throw .indexOutOfBounds(index: index.position.rawValue, count: _count)
        }
        return _storage[index.position.rawValue]!
    }

    // =========================================================================
    // SUBSCRIPT OPTION 4: Bounded index - TYPE encodes safety
    // =========================================================================
    // The TYPE `Bounded<capacity>` IS the indicator that this is capacity-bounded.
    // No label needed - the type speaks for itself.
    //
    // PRO: No runtime check, type encodes bounds proof
    // CON: Only safe when count == capacity (caller's responsibility)

    /// Access element at bounded index. NO PRECONDITION.
    ///
    /// The type `Index<Element>.Bounded<capacity>` proves `0 <= index < capacity`.
    /// For full arrays (`count == capacity`), this is sufficient - no check needed.
    ///
    /// ## Contract
    ///
    /// Caller must ensure `isFull == true`. If not, behavior is undefined.
    /// The TYPE is the documentation - `Bounded<capacity>` means capacity-proven.
    subscript(_ index: Index<Element>.Bounded<capacity>) -> Element {
        // Type proves: 0 <= index < capacity
        // Caller proves: count == capacity
        // Therefore: 0 <= index < count ✓
        _storage[index.rawValue]!
    }

    // =========================================================================
    // SUBSCRIPT OPTION 5: Borrowing closure (validates once)
    // =========================================================================
    // PRO: Total, validates once, enables further operations
    // CON: Closure-based API

    borrowing func withElement<R>(
        at index: Index<Element>,
        _ body: (borrowing Element) -> R
    ) -> R? {
        guard index < count else { return nil }
        return body(_storage[index.position.rawValue]!)
    }

    // =========================================================================
    // SUBSCRIPT OPTION 6: Validated index (closed-world)
    // =========================================================================
    // PRO: Type-level proof of validity
    // CON: More complex, requires obtaining ValidIndex first

    struct ValidIndex: Equatable {
        fileprivate let _position: Int
        fileprivate init(_ position: Int) { self._position = position }
    }

    /// Validates an index against current count.
    func validIndex(for index: Index<Element>) -> ValidIndex? {
        guard index < count else { return nil }
        return ValidIndex(index.position.rawValue)
    }

    /// Accesses element at validated index. TOTAL - no precondition.
    subscript(validated index: ValidIndex) -> Element {
        // SAFE: ValidIndex can only be created via validation
        _storage[index._position]!
    }
}

// ============================================================================
// PART 3: Demonstration
// ============================================================================

func demonstrateArrayTotality() {
    print("\n" + String(repeating: "=", count: 70))
    print("ARRAY TOTALITY PATTERNS")
    print(String(repeating: "=", count: 70) + "\n")

    var array = TotalInlineArray<Int, 8>()
    try! array.append(100)
    try! array.append(200)
    try! array.append(300)

    let validIdx: Index<Int> = try! Index(1)
    let invalidIdx: Index<Int> = try! Index(99)

    // Option 1: Preconditioned (skip - would crash)
    print("Option 1: subscript(preconditioned:) - SKIP (would crash on invalid)")
    print("  array[preconditioned: 1] = \(array[preconditioned: validIdx])")

    // Option 2: Safe subscript
    print("\nOption 2: subscript(safe:) - Optional return")
    print("  array[safe: 1] = \(array[safe: validIdx] as Any)")
    print("  array[safe: 99] = \(array[safe: invalidIdx] as Any)")

    // Option 3: Typed throws
    print("\nOption 3: element(at:) throws(AccessError)")
    do {
        let value = try array.element(at: validIdx)
        print("  try array.element(at: 1) = \(value)")
    } catch {
        print("  Error: \(error)")
    }
    do {
        let _ = try array.element(at: invalidIdx)
    } catch let error as TotalInlineArray<Int, 8>.AccessError {
        print("  try array.element(at: 99) throws \(error)")
    } catch {
        print("  Unexpected error")
    }

    // Option 4: Bounded index - TYPE is the indicator
    print("\nOption 4: subscript(_: Bounded<N>) - TYPE encodes safety")
    print("  Only safe when isFull == true (currently: \(array.isFull))")
    // Fill the array
    while !array.isFull {
        try! array.append(0)
    }
    let boundedIdx: Index<Int>.Bounded<8> = 1
    print("  After filling: array[boundedIdx] = \(array[boundedIdx])  // TYPE is Bounded<8>")

    // Reset for remaining demos
    array = TotalInlineArray<Int, 8>()
    try! array.append(100)
    try! array.append(200)
    try! array.append(300)

    // Option 5: Borrowing closure
    print("\nOption 5: withElement(at:_:) - Borrowing pattern")
    if let result = array.withElement(at: validIdx, { $0 * 2 }) {
        print("  array.withElement(at: 1) { $0 * 2 } = \(result)")
    }
    if array.withElement(at: invalidIdx, { $0 }) == nil {
        print("  array.withElement(at: 99) = nil")
    }

    // Option 6: Validated index
    print("\nOption 6: subscript(validated:) - Closed-world pattern")
    if let valid = array.validIndex(for: validIdx) {
        print("  array[validated: validIndex(1)] = \(array[validated: valid])")
    }
    if array.validIndex(for: invalidIdx) == nil {
        print("  validIndex(for: 99) = nil")
    }

    // Summary
    print("\n" + String(repeating: "-", count: 70))
    print("RECOMMENDATION FOR swift-array-primitives:")
    print(String(repeating: "-", count: 70))
    print("""

    1. KEEP subscript(_: Index<Element>) with precondition
       - Matches stdlib Array behavior
       - Users expect crash on invalid access

    2. ADD subscript(_: Index<Element>.Bounded<capacity>) WITHOUT precondition
       - TYPE encodes bounds proof - no label needed
       - For full arrays (count == capacity): completely safe
       - Caller ensures fullness; TYPE is the documentation

    3. ADD element(at:) throws(AccessError) -> Element
       - Total alternative for those who want error handling
       - Typed error enables exhaustive matching

    4. MODIFY withElement(at:_:) -> R? to return Optional
       - Already exists in Array.Inline
       - Change from precondition to nil return

    5. CONSIDER ValidIndex pattern for advanced use cases
       - Useful for algorithms that validate once, access many

    TYPE HIERARCHY encodes safety level:
 runtime bounds check
 no bounds check (type proves it)

    PERFORMANCE: All patterns are O(1). The TYPE determines WHERE
    the bounds check happens (construction vs access).

    """)
}

// Run demonstration (called from main.swift)
// demonstrateArrayTotality()

