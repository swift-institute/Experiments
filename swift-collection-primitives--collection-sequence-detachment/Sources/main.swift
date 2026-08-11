// MARK: - Collection / Sequence Protocol Detachment
//
// Purpose: Validate that Collection.Protocol can be detached from
//          Sequence.Protocol — standalone with Element: ~Copyable,
//          index-based algorithms, unified hierarchy with __ArrayProtocol,
//          dual conformance, and ForEach overload resolution.
//
// Hypothesis: Removing Sequence.Protocol inheritance from Collection.Protocol
//             enables: (1) ~Copyable elements throughout the Collection hierarchy,
//             (2) __ArrayProtocol conforming to Collection.Protocol,
//             (3) index-based algorithms replacing iterator-based ones,
//             (4) independent dual conformance without ambiguity.
//
// Risks being tested:
//   1. Standalone Collection.Protocol with Element: ~Copyable + subscript
//   2. Index-based Count, Min, Max algorithms (replacing iterator-based)
//   3. __ArrayProtocol: Collection.Bidirectional with Element: ~Copyable
//   4. Dual conformance: type conforms to BOTH Collection.Protocol AND Sequence.Protocol
//   5. ForEach overload resolution with two tags (no ambiguity)
//   6. ~Copyable elements through the unified Collection hierarchy
//   7. Collection.Clearable standalone (no Sequence.Clearable dependency)
//
// Result:    CONFIRMED — all 23 tests pass. Standalone Collection.Protocol
//            with Element: ~Copyable works. Index-based Count/Min/Max replace
//            iterator-based. __ArrayProtocol conforms to unified hierarchy.
//            Dual conformance (Collection + Sequence) works independently.
//            ForEach overload resolution with two tags: no ambiguity.
//            ~Copyable elements work throughout (subscript via _read coroutine).
//            Collection.Clearable works standalone without Sequence.Clearable.
//
// Toolchain: Swift 6.2.3, Xcode 26.0 beta 2 (16A5171r)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Platform:  macOS 26.0 (25A5279m), Apple M4
// Date:      2026-02-23

// ============================================================================
// MARK: - 1. Phantom-Typed Index (simplified stand-in for Index<Element>)
// ============================================================================

/// Simplified phantom-typed index. Stand-in for `Index_Primitives.Index<Element>`.
struct PhantomIndex<Element: ~Copyable>: Comparable, Sendable {
    let rawValue: Int

    init(_ rawValue: Int) { self.rawValue = rawValue }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

// ============================================================================
// MARK: - 2. Sequence.Protocol (unchanged, separate)
// ============================================================================

/// Stand-in for Sequence.Iterator.Protocol.
protocol SequenceIteratorProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    mutating func next() -> Element?
}

/// Stand-in for Sequence.Protocol — independent of Collection.
protocol SequenceProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: SequenceIteratorProtocol & ~Copyable
        where Iterator.Element == Element
    borrowing func makeIterator() -> Iterator
}

// ============================================================================
// MARK: - 3. Collection.Protocol (STANDALONE — no Sequence inheritance)
// ============================================================================

/// Stand-in for Collection.Protocol after detachment.
/// Key change: does NOT inherit from SequenceProtocol.
protocol CollectionProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    typealias Index = PhantomIndex<Element>

    var startIndex: Index { get }
    var endIndex: Index { get }
    subscript(_ position: Index) -> Element { get }
    func index(after i: Index) -> Index
}

// ============================================================================
// MARK: - 4. Collection.Indexed (pure navigation, no Element)
// ============================================================================

/// Stand-in for Collection.Indexed — index navigation without Element.
protocol CollectionIndexed: ~Copyable {
    associatedtype Index: Comparable
    var startIndex: Index { get }
    var endIndex: Index { get }
    func index(after i: Index) -> Index
}

extension CollectionIndexed where Self: ~Copyable {
    var isEmpty: Bool { startIndex == endIndex }
}

// ============================================================================
// MARK: - 5. Collection.Bidirectional (adds index(before:))
// ============================================================================

/// Stand-in for Collection.Bidirectional.
protocol CollectionBidirectional: CollectionIndexed & ~Copyable {
    func index(before i: Index) -> Index
}

// ============================================================================
// MARK: - 6. __ArrayProtocol (unified: Bidirectional + Element + subscript)
// ============================================================================

/// Stand-in for __ArrayProtocol.
/// KEY TEST: Conforms to BOTH CollectionBidirectional AND CollectionProtocol.
/// Element is inherited from CollectionProtocol — no redeclaration needed.
protocol ArrayProtocol: CollectionBidirectional & CollectionProtocol & ~Copyable {
    subscript(index: PhantomIndex<Element>) -> Element { get set }
}

// ============================================================================
// MARK: - 7. Collection.Clearable (standalone, no Sequence.Clearable)
// ============================================================================

/// Stand-in for Collection.Clearable after detachment.
/// Key change: inherits from CollectionProtocol only, NOT Sequence.Clearable.
protocol CollectionClearable: CollectionProtocol & ~Copyable {
    mutating func removeAll()
}

// ============================================================================
// MARK: - 8. ForEach Tags (two separate tags)
// ============================================================================

/// Stand-in for Collection.ForEach tag.
enum CollectionForEach {}

/// Stand-in for Sequence.ForEach tag.
enum SequenceForEach {}

// ============================================================================
// MARK: - 9. Simplified Property.View (stand-in)
// ============================================================================

/// Minimal Property.View stand-in for testing ForEach overload resolution.
struct PropertyView<Base: ~Copyable, Tag> {
    let pointer: UnsafePointer<Base>

    init(_ pointer: UnsafePointer<Base>) {
        self.pointer = pointer
    }
}

// Collection.ForEach — index-based iteration
extension PropertyView where Base: CollectionProtocol & ~Copyable, Tag == CollectionForEach {
    func callAsFunction(_ body: (borrowing Base.Element) -> Void) {
        var index = pointer.pointee.startIndex
        let endIndex = pointer.pointee.endIndex
        while index < endIndex {
            body(pointer.pointee[index])
            index = pointer.pointee.index(after: index)
        }
    }
}

// Sequence.ForEach — iterator-based iteration
extension PropertyView where Base: SequenceProtocol & ~Copyable, Tag == SequenceForEach {
    func callAsFunction(_ body: (borrowing Base.Element) -> Void) {
        var iterator = pointer.pointee.makeIterator()
        while let element = iterator.next() {
            body(element)
        }
    }
}

// ============================================================================
// MARK: - 10. Index-Based Algorithms (replacing iterator-based)
// ============================================================================

// Count.all — index-based
func indexBasedCount<C: CollectionProtocol & ~Copyable>(
    _ collection: borrowing C
) -> Int {
    var count = 0
    var index = collection.startIndex
    let endIndex = collection.endIndex
    while index < endIndex {
        count += 1
        index = collection.index(after: index)
    }
    return count
}

// Count.where — index-based
func indexBasedCountWhere<C: CollectionProtocol & ~Copyable>(
    _ collection: borrowing C,
    where predicate: (borrowing C.Element) -> Bool
) -> Int {
    var count = 0
    var index = collection.startIndex
    let endIndex = collection.endIndex
    while index < endIndex {
        if predicate(collection[index]) { count += 1 }
        index = collection.index(after: index)
    }
    return count
}

// Min — index-based (requires Copyable for result storage)
func indexBasedMin<C: CollectionProtocol & ~Copyable>(
    _ collection: borrowing C,
    by isLess: (borrowing C.Element, borrowing C.Element) -> Bool
) -> C.Element? where C.Element: Copyable {
    var index = collection.startIndex
    let endIndex = collection.endIndex
    guard index < endIndex else { return nil }
    var result = collection[index]
    index = collection.index(after: index)
    while index < endIndex {
        if isLess(collection[index], result) {
            result = collection[index]
        }
        index = collection.index(after: index)
    }
    return result
}

// Max — index-based (requires Copyable for result storage)
func indexBasedMax<C: CollectionProtocol & ~Copyable>(
    _ collection: borrowing C,
    by isGreater: (borrowing C.Element, borrowing C.Element) -> Bool
) -> C.Element? where C.Element: Copyable {
    var index = collection.startIndex
    let endIndex = collection.endIndex
    guard index < endIndex else { return nil }
    var result = collection[index]
    index = collection.index(after: index)
    while index < endIndex {
        if isGreater(collection[index], result) {
            result = collection[index]
        }
        index = collection.index(after: index)
    }
    return result
}

// ============================================================================
// MARK: - 11. Concrete Types
// ============================================================================

// --- Copyable array conforming to the full hierarchy ---

struct TestArray<Element: Copyable>: ~Copyable {
    var storage: [Element]
    var _count: Int { storage.count }
}

extension TestArray: CollectionIndexed {
    typealias Index = PhantomIndex<Element>
    var startIndex: Index { Index(0) }
    var endIndex: Index { Index(_count) }
    func index(after i: Index) -> Index { Index(i.rawValue + 1) }
}

extension TestArray: CollectionBidirectional {
    func index(before i: Index) -> Index { Index(i.rawValue - 1) }
}

// Single subscript satisfies both CollectionProtocol { get } and ArrayProtocol { get set }
extension TestArray: CollectionProtocol & ArrayProtocol {
    subscript(_ position: PhantomIndex<Element>) -> Element {
        get { storage[position.rawValue] }
        set { storage[position.rawValue] = newValue }
    }
}

// --- Iterator for Sequence.Protocol conformance ---

struct TestArrayIterator<Element: Copyable>: ~Copyable, SequenceIteratorProtocol {
    let storage: [Element]
    var index: Int = 0

    mutating func next() -> Element? {
        guard index < storage.count else { return nil }
        defer { index += 1 }
        return storage[index]
    }
}

// Dual conformance: TestArray conforms to Sequence.Protocol independently
extension TestArray: SequenceProtocol {
    borrowing func makeIterator() -> TestArrayIterator<Element> {
        TestArrayIterator(storage: storage)
    }
}

// --- Clearable conformance ---

extension TestArray: CollectionClearable {
    mutating func removeAll() {
        storage.removeAll()
    }
}

// --- ~Copyable element array ---

struct UniqueItem: ~Copyable {
    let value: Int
    init(_ value: Int) { self.value = value }
}

struct NoncopyableArray: ~Copyable {
    private var ptr: UnsafeMutablePointer<UniqueItem>
    private(set) var count: Int

    init(_ values: [Int]) {
        self.count = values.count
        self.ptr = .allocate(capacity: values.count)
        for (i, v) in values.enumerated() {
            (ptr + i).initialize(to: UniqueItem(v))
        }
    }

    deinit {
        for i in 0..<count {
            (ptr + i).deinitialize(count: 1)
        }
        ptr.deallocate()
    }
}

extension NoncopyableArray: CollectionIndexed {
    typealias Index = PhantomIndex<UniqueItem>
    var startIndex: Index { Index(0) }
    var endIndex: Index { Index(count) }
    func index(after i: Index) -> Index { Index(i.rawValue + 1) }
}

extension NoncopyableArray: CollectionBidirectional {
    func index(before i: Index) -> Index { Index(i.rawValue - 1) }
}

extension NoncopyableArray: CollectionProtocol {
    subscript(_ position: Index) -> UniqueItem {
        // _read yields a borrowed reference — no consuming move.
        // Protocol declares { get }, but _read satisfies it for ~Copyable.
        _read {
            let p = ptr + position.rawValue
            yield p.pointee
        }
    }
}

// ============================================================================
// MARK: - 12. Generic Functions Over Unified Protocol
// ============================================================================

/// Generic function that works with ANY CollectionProtocol conformer.
func genericForEach<C: CollectionProtocol & ~Copyable>(
    _ collection: borrowing C,
    body: (borrowing C.Element) -> Void
) {
    var index = collection.startIndex
    let endIndex = collection.endIndex
    while index < endIndex {
        body(collection[index])
        index = collection.index(after: index)
    }
}

/// Generic function constrained to ArrayProtocol (unified hierarchy).
func genericArrayForEach<A: ArrayProtocol & ~Copyable>(
    _ array: borrowing A,
    body: (borrowing A.Element) -> Void
) {
    var index = array.startIndex
    let endIndex = array.endIndex
    while index < endIndex {
        body(array[index])
        index = array.index(after: index)
    }
}

// ============================================================================
// MARK: - 13. Tests
// ============================================================================

func test_standaloneCollectionProtocol() {
    print("Test 1: Standalone Collection.Protocol (no Sequence inheritance)")
    let array = TestArray(storage: [10, 20, 30, 40, 50])

    // Index-based access works
    assert(array[PhantomIndex(0)] == 10)
    assert(array[PhantomIndex(4)] == 50)
    assert(array.startIndex == PhantomIndex(0))
    assert(array.endIndex == PhantomIndex(5))
    print("  [PASS] Index-based subscript access works")

    // isEmpty from CollectionIndexed default
    assert(!array.isEmpty)
    let empty = TestArray<Int>(storage: [])
    assert(empty.isEmpty)
    print("  [PASS] isEmpty default from CollectionIndexed works")
}

func test_indexBasedAlgorithms() {
    print("Test 2: Index-based algorithms (replacing iterator-based)")
    let array = TestArray(storage: [3, 1, 4, 1, 5, 9, 2, 6])

    // count.all
    let total = indexBasedCount(array)
    assert(total == 8, "Count should be 8")
    print("  [PASS] count.all = \(total)")

    // count.where (even numbers)
    let evens = indexBasedCountWhere(array, where: { element in
        let val: Int = element
        return val % 2 == 0
    })
    assert(evens == 3, "Even count should be 3 (4, 2, 6)")
    print("  [PASS] count.where(even) = \(evens)")

    // min
    let minimum = indexBasedMin(array, by: { a, b in
        let la: Int = a; let lb: Int = b
        return la < lb
    })
    assert(minimum == 1, "Min should be 1")
    print("  [PASS] min = \(minimum!)")

    // max
    let maximum = indexBasedMax(array, by: { a, b in
        let la: Int = a; let lb: Int = b
        return la > lb
    })
    assert(maximum == 9, "Max should be 9")
    print("  [PASS] max = \(maximum!)")

    // empty collection
    let emptyArray = TestArray<Int>(storage: [])
    let emptyMin = indexBasedMin(emptyArray, by: { a, b in
        let la: Int = a; let lb: Int = b
        return la < lb
    })
    assert(emptyMin == nil, "Min of empty should be nil")
    print("  [PASS] min(empty) = nil")
}

func test_arrayProtocolUnification() {
    print("Test 3: __ArrayProtocol conforms to Collection.Protocol (unified hierarchy)")
    let array = TestArray(storage: [100, 200, 300])

    // Works through CollectionProtocol
    var collectionElements: [Int] = []
    genericForEach(array) { element in
        let val: Int = element
        collectionElements.append(val)
    }
    assert(collectionElements == [100, 200, 300])
    print("  [PASS] genericForEach(CollectionProtocol) works")

    // Works through ArrayProtocol
    var arrayElements: [Int] = []
    genericArrayForEach(array) { element in
        let val: Int = element
        arrayElements.append(val)
    }
    assert(arrayElements == [100, 200, 300])
    print("  [PASS] genericArrayForEach(ArrayProtocol) works")

    // Bidirectional: index(before:)
    let lastIndex = array.index(before: array.endIndex)
    assert(array[lastIndex] == 300)
    print("  [PASS] Bidirectional index(before:) works")
}

func test_dualConformance() {
    print("Test 4: Dual conformance (Collection.Protocol + Sequence.Protocol)")
    let array = TestArray(storage: [7, 8, 9])

    // Access via CollectionProtocol (index-based)
    let count = indexBasedCount(array)
    assert(count == 3)
    print("  [PASS] CollectionProtocol access works")

    // Access via SequenceProtocol (iterator-based) — independent
    var iterator = array.makeIterator()
    var seqElements: [Int] = []
    while let element = iterator.next() {
        seqElements.append(element)
    }
    assert(seqElements == [7, 8, 9])
    print("  [PASS] SequenceProtocol access works independently")

    // Both work on the same instance
    print("  [PASS] Dual conformance: same type, both protocols, no ambiguity")
}

func test_forEachOverloadResolution() {
    print("Test 5: ForEach overload resolution (two tags)")
    let array = TestArray(storage: [1, 2, 3])

    // Collection.ForEach (index-based) — via PropertyView
    var collectionResult: [Int] = []
    withUnsafePointer(to: array) { ptr in
        let view = PropertyView<TestArray<Int>, CollectionForEach>(ptr)
        view { element in
            let val: Int = element
            collectionResult.append(val)
        }
    }
    assert(collectionResult == [1, 2, 3])
    print("  [PASS] CollectionForEach tag → index-based iteration")

    // Sequence.ForEach (iterator-based) — via PropertyView
    var sequenceResult: [Int] = []
    withUnsafePointer(to: array) { ptr in
        let view = PropertyView<TestArray<Int>, SequenceForEach>(ptr)
        view { element in
            let val: Int = element
            sequenceResult.append(val)
        }
    }
    assert(sequenceResult == [1, 2, 3])
    print("  [PASS] SequenceForEach tag → iterator-based iteration")

    // Both produce same results
    assert(collectionResult == sequenceResult)
    print("  [PASS] Both tags produce identical results, no ambiguity")
}

func test_noncopyableElements() {
    print("Test 6: ~Copyable elements through Collection hierarchy")
    let array = NoncopyableArray([10, 20, 30, 40])

    // Index-based access with ~Copyable elements
    assert(array[PhantomIndex(0)].value == 10)
    assert(array[PhantomIndex(3)].value == 40)
    print("  [PASS] Subscript access to ~Copyable elements works")

    // Generic forEach with ~Copyable elements
    var values: [Int] = []
    genericForEach(array) { element in
        values.append(element.value)
    }
    assert(values == [10, 20, 30, 40])
    print("  [PASS] genericForEach with ~Copyable elements works")

    // Count
    let count = indexBasedCount(array)
    assert(count == 4)
    print("  [PASS] indexBasedCount with ~Copyable elements = \(count)")

    // Count.where
    let bigCount = indexBasedCountWhere(array, where: { element in
        element.value > 20
    })
    assert(bigCount == 2)
    print("  [PASS] indexBasedCountWhere(>20) with ~Copyable = \(bigCount)")

    // Bidirectional access
    let lastIdx = array.index(before: array.endIndex)
    assert(array[lastIdx].value == 40)
    print("  [PASS] Bidirectional index(before:) with ~Copyable elements")
}

func test_clearable() {
    print("Test 7: Collection.Clearable (standalone, no Sequence.Clearable)")
    var array = TestArray(storage: [1, 2, 3, 4, 5])

    // Verify non-empty
    assert(!array.isEmpty)
    let preCount = indexBasedCount(array)
    assert(preCount == 5)
    print("  [PASS] Pre-clear count = \(preCount)")

    // Clear
    array.removeAll()
    assert(array.isEmpty)
    let postCount = indexBasedCount(array)
    assert(postCount == 0)
    print("  [PASS] Post-clear count = \(postCount), isEmpty = true")
}

func test_multipleIteration() {
    print("Test 8: Multiple iteration over ~Copyable collection")
    let array = NoncopyableArray([5, 10, 15])

    // First pass
    var pass1: [Int] = []
    genericForEach(array) { pass1.append($0.value) }

    // Second pass — collection not consumed
    var pass2: [Int] = []
    genericForEach(array) { pass2.append($0.value) }

    assert(pass1 == pass2)
    print("  [PASS] Multiple passes: \(pass1) == \(pass2)")
}

// ============================================================================
// MARK: - Run All Tests
// ============================================================================

print("=== Collection / Sequence Detachment Experiment ===")
print()

test_standaloneCollectionProtocol()
print()

test_indexBasedAlgorithms()
print()

test_arrayProtocolUnification()
print()

test_dualConformance()
print()

test_forEachOverloadResolution()
print()

test_noncopyableElements()
print()

test_clearable()
print()

test_multipleIteration()
print()

print("=== All tests passed ===")
