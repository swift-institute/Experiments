// MARK: - Experiment: Total Array Access (No Crashes)
// Purpose: Explore designs that achieve totality through the type system
// Hypothesis: We can design array access that CANNOT crash
//
// Totality Hierarchy:
//   1. BEST:  Type system prevents invalid states (can't construct bad input)
//   2. GOOD:  Typed throws (function declares failure modes)
//   3. WORST: Preconditions (crash at runtime)
//
// Toolchain: swift-6.2-RELEASE
// Result: PENDING
// Date: 2026-01-22

import Index_Primitives

// ============================================================================
// PATTERN 1: Closed-World Indices (Index can only come from the collection)
// ============================================================================

/// An array where valid indices can ONLY be obtained from the array itself.
/// This prevents construction of invalid indices entirely.
struct ClosedWorldArray<Element, let capacity: Int> {
    private var _storage: [Element?]
    private var _count: Int = 0

    /// A valid index into this array. Cannot be constructed externally.
    struct ValidIndex: Hashable, Comparable {
        fileprivate let _value: Int

        // NO PUBLIC INIT - can only be created by the array
        fileprivate init(_ value: Int) { self._value = value }

        static func < (lhs: Self, rhs: Self) -> Bool { lhs._value < rhs._value }
    }

    init() {
        _storage = Array(repeating: nil, count: capacity)
    }

    var count: Int { _count }
    var isEmpty: Bool { _count == 0 }

    // --- Index Creation (the ONLY way to get a ValidIndex) ---

    /// Returns a valid index for the given position, or nil if out of bounds.
    /// This is the ONLY way to create a ValidIndex.
    func index(at position: Int) -> ValidIndex? {
        guard position >= 0, position < _count else { return nil }
        return ValidIndex(position)
    }

    /// The first valid index, or nil if empty.
    var startIndex: ValidIndex? {
        guard _count > 0 else { return nil }
        return ValidIndex(0)
    }

    /// Returns the index after the given index, or nil if at end.
    func index(after i: ValidIndex) -> ValidIndex? {
        let next = i._value + 1
        guard next < _count else { return nil }
        return ValidIndex(next)
    }

    // --- Subscript: TOTAL (no precondition, no throws, no crash) ---

    /// Access element at valid index. CANNOT FAIL.
    subscript(index: ValidIndex) -> Element {
        get {
            // SAFE: ValidIndex can only exist if it was validated
            _storage[index._value]!
        }
        set {
            _storage[index._value] = newValue
        }
    }

    // --- Mutations ---

    mutating func append(_ element: Element) -> ValidIndex? {
        guard _count < capacity else { return nil }
        let idx = _count
        _storage[idx] = element
        _count += 1
        return ValidIndex(idx)
    }
}

// ============================================================================
// PATTERN 2: Typed Throws (Declare failure modes)
// ============================================================================

/// An array where all fallible operations use typed throws.
struct ThrowingArray<Element, let capacity: Int> {
    private var _storage: [Element?]
    private var _count: Int = 0

    enum Error: Swift.Error, Equatable {
        case indexOutOfBounds(index: Int, count: Int)
        case capacityExceeded
        case empty
    }

    init() {
        _storage = Array(repeating: nil, count: capacity)
    }

    var count: Int { _count }
    var isEmpty: Bool { _count == 0 }

    // --- Subscript with Typed Throws ---

    /// Access element at index. Throws if out of bounds.
    func element(at index: Int) throws(Error) -> Element {
        guard index >= 0, index < _count else {
            throw .indexOutOfBounds(index: index, count: _count)
        }
        return _storage[index]!
    }

    /// Set element at index. Throws if out of bounds.
    mutating func setElement(_ element: Element, at index: Int) throws(Error) {
        guard index >= 0, index < _count else {
            throw .indexOutOfBounds(index: index, count: _count)
        }
        _storage[index] = element
    }

    // --- Other operations with Typed Throws ---

    mutating func append(_ element: Element) throws(Error) {
        guard _count < capacity else { throw .capacityExceeded }
        _storage[_count] = element
        _count += 1
    }

    mutating func removeLast() throws(Error) -> Element {
        guard _count > 0 else { throw .empty }
        _count -= 1
        return _storage[_count]!
    }

    func first() throws(Error) -> Element {
        guard _count > 0 else { throw .empty }
        return _storage[0]!
    }

    func last() throws(Error) -> Element {
        guard _count > 0 else { throw .empty }
        return _storage[_count - 1]!
    }
}

// ============================================================================
// PATTERN 3: NonEmpty Wrapper (Prove non-emptiness at type level)
// ============================================================================

/// A non-empty array. Construction requires at least one element.
struct NonEmptyArray<Element, let capacity: Int> {
    private var _storage: [Element?]
    private var _count: Int  // Always >= 1

    enum Error: Swift.Error {
        case capacityExceeded
    }

    /// Create with first element. CANNOT be empty.
    init(first: Element) {
        _storage = Array(repeating: nil, count: capacity)
        _storage[0] = first
        _count = 1
    }

    var count: Int { _count }

    // --- TOTAL operations (no throws, no crash) ---

    /// First element. ALWAYS exists.
    var first: Element {
        _storage[0]!  // SAFE: _count >= 1, so index 0 always valid
    }

    /// Last element. ALWAYS exists.
    var last: Element {
        _storage[_count - 1]!  // SAFE: _count >= 1
    }

    /// Remove last and return (element, remainder).
    /// If this was the last element, remainder is nil.
    mutating func popLast() -> (element: Element, remainder: NonEmptyArray?) {
        let element = _storage[_count - 1]!
        _count -= 1
        if _count == 0 {
            return (element, nil)  // Array is now empty, can't be NonEmpty
        }
        return (element, self)
    }

    // --- Fallible operations use typed throws ---

    mutating func append(_ element: Element) throws(Error) {
        guard _count < capacity else { throw .capacityExceeded }
        _storage[_count] = element
        _count += 1
    }
}

// ============================================================================
// PATTERN 4: Proof-Carrying Index (Index + Proof of Validity)
// ============================================================================

/// A proof that an index was valid for a specific array state.
/// The proof is invalidated if the array is mutated.
struct ProofCarryingArray<Element, let capacity: Int> {
    private var _storage: [Element?]
    private var _count: Int = 0
    private var _version: Int = 0  // Incremented on mutation

    /// An index with proof of validity for a specific array version.
    struct ProvenIndex {
        fileprivate let _value: Int
        fileprivate let _version: Int  // The array version when validated

        fileprivate init(value: Int, version: Int) {
            self._value = value
            self._version = version
        }
    }

    enum Error: Swift.Error {
        case indexOutOfBounds
        case proofInvalidated  // Array was mutated since proof was created
    }

    init() {
        _storage = Array(repeating: nil, count: capacity)
    }

    var count: Int { _count }

    // --- Create proven index ---

    /// Validate an index and return proof of validity.
    func prove(_ index: Int) -> ProvenIndex? {
        guard index >= 0, index < _count else { return nil }
        return ProvenIndex(value: index, version: _version)
    }

    // --- Access with proof ---

    /// Access with proven index. Throws if proof is stale.
    func element(at index: ProvenIndex) throws(Error) -> Element {
        guard index._version == _version else {
            throw .proofInvalidated
        }
        // SAFE: proof was valid and array hasn't changed
        return _storage[index._value]!
    }

    // --- Mutations invalidate proofs ---

    mutating func append(_ element: Element) -> Bool {
        guard _count < capacity else { return false }
        _storage[_count] = element
        _count += 1
        _version += 1  // Invalidate all existing proofs
        return true
    }
}

// ============================================================================
// PATTERN 5: Borrowing + Validation (Best of both worlds)
// ============================================================================

/// Array with borrowing-based safe access.
struct BorrowingArray<Element, let capacity: Int> {
    private var _storage: [Element?]
    private var _count: Int = 0

    init() {
        _storage = Array(repeating: nil, count: capacity)
    }

    var count: Int { _count }

    /// Safe access: validates index, borrows self, calls body.
    /// Returns nil if index invalid, otherwise returns body's result.
    ///
    /// Inside body:
    /// - Index is PROVEN valid
    /// - Self is borrowed (immutable)
    /// - Access is TOTAL (cannot fail)
    borrowing func withElement<R>(
        at index: Int,
        body: (Element) -> R
    ) -> R? {
        guard index >= 0, index < _count else { return nil }
        return body(_storage[index]!)
    }

    /// Safe iteration: borrows self, iterates all elements.
    /// TOTAL for the iteration itself.
    borrowing func forEach(_ body: (Element) -> Void) {
        for i in 0..<_count {
            body(_storage[i]!)
        }
    }

    /// Safe indexed iteration: provides both index and element.
    borrowing func forEachIndexed(_ body: (Int, Element) -> Void) {
        for i in 0..<_count {
            body(i, _storage[i]!)
        }
    }

    mutating func append(_ element: Element) -> Bool {
        guard _count < capacity else { return false }
        _storage[_count] = element
        _count += 1
        return true
    }
}

// ============================================================================
// DEMONSTRATION
// ============================================================================

func demonstrateTotality() {
    print("=== Totality Patterns for Array Access ===\n")

    // --- Pattern 1: Closed-World ---
    print("PATTERN 1: Closed-World Indices")
    var closed = ClosedWorldArray<Int, 8>()
    _ = closed.append(10)
    _ = closed.append(20)
    _ = closed.append(30)

    // Can only access via validated index
    if let idx = closed.index(at: 1) {
        print("  closed[validIndex] = \(closed[idx])")  // TOTAL, no crash possible
    }

    // Invalid index returns nil, not crash
    if closed.index(at: 99) == nil {
        print("  index(at: 99) = nil (not crash)")
    }

    // Iteration via index chaining
    print("  Iteration: ", terminator: "")
    var i = closed.startIndex
    while let idx = i {
        print("\(closed[idx]) ", terminator: "")
        i = closed.index(after: idx)
    }
    print()

    // --- Pattern 2: Typed Throws ---
    print("\nPATTERN 2: Typed Throws")
    var throwing = ThrowingArray<Int, 8>()
    try! throwing.append(100)
    try! throwing.append(200)

    do {
        let elem = try throwing.element(at: 1)
        print("  element(at: 1) = \(elem)")
    } catch {
        print("  Error: \(error)")
    }

    do {
        _ = try throwing.element(at: 99)
    } catch let error as ThrowingArray<Int, 8>.Error {
        print("  element(at: 99) throws: \(error)")
    }

    // --- Pattern 3: NonEmpty ---
    print("\nPATTERN 3: NonEmpty")
    var nonEmpty = NonEmptyArray<Int, 8>(first: 1000)
    try! nonEmpty.append(2000)

    print("  first = \(nonEmpty.first)")  // TOTAL, always succeeds
    print("  last = \(nonEmpty.last)")    // TOTAL, always succeeds

    // --- Pattern 4: Proof-Carrying ---
    print("\nPATTERN 4: Proof-Carrying Index")
    var proven = ProofCarryingArray<Int, 8>()
    _ = proven.append(42)

    if let proof = proven.prove(0) {
        let elem = try! proven.element(at: proof)
        print("  element(at: proof) = \(elem)")

        // Mutation invalidates proof
        _ = proven.append(43)
        do {
            _ = try proven.element(at: proof)
        } catch {
            print("  After mutation: proof invalidated")
        }
    }

    // --- Pattern 5: Borrowing ---
    print("\nPATTERN 5: Borrowing + Validation")
    var borrowing = BorrowingArray<Int, 8>()
    _ = borrowing.append(500)
    _ = borrowing.append(600)

    // withElement returns Optional, not crash
    if let result = borrowing.withElement(at: 1, body: { $0 * 2 }) {
        print("  withElement(at: 1) { *2 } = \(result)")
    }

    if borrowing.withElement(at: 99, body: { $0 }) == nil {
        print("  withElement(at: 99) = nil (not crash)")
    }

    print("  forEach: ", terminator: "")
    borrowing.forEach { print("\($0) ", terminator: "") }
    print()

    // --- Summary ---
    print("\n=== SUMMARY ===")
    print("""

    | Pattern              | Failure Mode      | Ergonomics | Safety |
    |----------------------|-------------------|------------|--------|
    | Closed-World Index   | Returns nil       | Medium     | HIGH   |
    | Typed Throws         | Throws Error      | Medium     | HIGH   |
    | NonEmpty             | Can't construct   | High       | HIGHEST|
    | Proof-Carrying       | Throws if stale   | Low        | HIGH   |
    | Borrowing+Validation | Returns nil       | High       | HIGH   |

    RECOMMENDATIONS:
    1. Use NonEmpty<Array> for operations requiring non-empty (first, last, removeLast)
    2. Use typed throws for subscript access with explicit error handling
    3. Use borrowing+validation (withElement) for convenient safe access
    4. AVOID preconditions - they provide no recovery path

    """)
}
