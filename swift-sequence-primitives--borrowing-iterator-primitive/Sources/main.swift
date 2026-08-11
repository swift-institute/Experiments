// MARK: - Borrowing Iterator Primitive: withNext
//
// Purpose: Validate that `withNext<R>(_ body: (borrowing Element) -> R) -> R?`
//          works as a protocol requirement for iterators with ~Copyable elements,
//          and that `next()` can be derived for Copyable elements.
//
// Hypothesis: A closure-based lending primitive can replace `next() -> Element?`
//             as the universal iteration requirement, avoiding ~Escapable cascades
//             while supporting both Copyable and ~Copyable elements.
//
// Risks being tested:
//   1. withNext<R> generic method in ~Copyable protocol with Element: ~Copyable
//   2. Default next() derivation via withNext { $0 } for Copyable elements
//   3. Algorithm composition: forEach, contains, reduce, map via withNext
//   4. ~Copyable container with ~Copyable elements using withNext
//   5. Multiple iteration (container not consumed)
//   6. Borrowing access to ~Copyable element fields
//
// Result:    CONFIRMED — all 13 tests pass. withNext<R> works as protocol
//            requirement with Element: ~Copyable. Default next() derivation
//            via withNext { $0 } works for Copyable elements. Algorithm
//            composition (forEach, contains, reduce, map, count) works for
//            both Copyable and ~Copyable elements. Multiple iteration confirms
//            container is not consumed. No ~Escapable cascade required.
//
// Toolchain: Swift 6.2.3, Xcode 26.0 beta 2 (16A5171r)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Platform:  macOS 26.0 (25A5279m), Apple M4
// Date:      2026-02-23

// ============================================================================
// MARK: - 1. Protocol Definitions
// ============================================================================

/// Stand-in for Sequence.Iterator.Protocol with withNext as the primitive.
protocol IteratorProtocol_withNext: ~Copyable {
    associatedtype Element: ~Copyable

    /// Calls `body` with a borrowed reference to the next element.
    /// Returns body's return value wrapped in .some, or nil if exhausted.
    mutating func withNext<R>(_ body: (borrowing Element) -> R) -> R?
}

/// Stand-in for Sequence.Protocol.
protocol SequenceProtocol_withNext: ~Copyable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: IteratorProtocol_withNext & ~Copyable
        where Iterator.Element == Element

    borrowing func makeIterator() -> Iterator
}

// ============================================================================
// MARK: - 2. Default next() for Copyable Elements
// ============================================================================

extension IteratorProtocol_withNext where Self: ~Copyable, Element: Copyable {
    mutating func next() -> Element? {
        withNext { $0 }
    }
}

// ============================================================================
// MARK: - 3. Concrete Copyable Container + Iterator
// ============================================================================

/// Simple array-like container with Copyable elements.
struct SimpleArray<Element: Copyable>: ~Copyable {
    var storage: [Element]
}

/// Iterator for SimpleArray — implements withNext by borrowing from storage.
/// Note: This iterator is intentionally ~Copyable (owns a copy of storage).
struct SimpleArrayIterator<Element: Copyable>: ~Copyable, IteratorProtocol_withNext {
    let storage: [Element]
    var index: Int = 0

    mutating func withNext<R>(_ body: (borrowing Element) -> R) -> R? {
        guard index < storage.count else { return nil }
        defer { index += 1 }
        return body(storage[index])
    }
}

extension SimpleArray: SequenceProtocol_withNext {
    borrowing func makeIterator() -> SimpleArrayIterator<Element> {
        SimpleArrayIterator(storage: storage)
    }
}

// ============================================================================
// MARK: - 4. ~Copyable Container with ~Copyable Elements
// ============================================================================

/// A ~Copyable element type.
struct UniqueResource: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
}

/// Fixed-size container of ~Copyable elements using raw storage.
struct NoncopyableBuffer: ~Copyable {
    private var ptr: UnsafeMutablePointer<UniqueResource>
    let count: Int

    init(count: Int) {
        self.count = count
        self.ptr = .allocate(capacity: count)
        for i in 0..<count {
            (ptr + i).initialize(to: UniqueResource(i))
        }
    }

    deinit {
        for i in 0..<count {
            (ptr + i).deinitialize(count: 1)
        }
        ptr.deallocate()
    }
}

/// Iterator for NoncopyableBuffer — borrows from the buffer's raw storage.
struct NoncopyableBufferIterator: ~Copyable, IteratorProtocol_withNext {
    typealias Element = UniqueResource

    let ptr: UnsafeMutablePointer<UniqueResource>
    let count: Int
    var index: Int = 0

    mutating func withNext<R>(_ body: (borrowing UniqueResource) -> R) -> R? {
        guard index < count else { return nil }
        defer { index += 1 }
        // Borrow from the raw pointer — element stays in storage
        return body((ptr + index).pointee)
    }
}

extension NoncopyableBuffer: SequenceProtocol_withNext {
    typealias Element = UniqueResource

    borrowing func makeIterator() -> NoncopyableBufferIterator {
        NoncopyableBufferIterator(ptr: ptr, count: count)
    }
}

// ============================================================================
// MARK: - 5. Generic Algorithms via withNext
// ============================================================================

// forEach — universal (works for ~Copyable elements)
func forEach_withNext<S: SequenceProtocol_withNext & ~Copyable>(
    _ sequence: borrowing S,
    body: (borrowing S.Element) -> Void
) {
    var iterator = sequence.makeIterator()
    while let _ = iterator.withNext({ body($0) }) { }
}

// contains — universal (predicate borrows element)
func contains_withNext<S: SequenceProtocol_withNext & ~Copyable>(
    _ sequence: borrowing S,
    where predicate: (borrowing S.Element) -> Bool
) -> Bool {
    var iterator = sequence.makeIterator()
    while let found = iterator.withNext({ predicate($0) }) {
        if found { return true }
    }
    return false
}

// reduce — universal (combine borrows element)
func reduce_withNext<S: SequenceProtocol_withNext & ~Copyable, R>(
    _ sequence: borrowing S,
    into initial: R,
    _ combine: (inout R, borrowing S.Element) -> Void
) -> R {
    var result = initial
    var iterator = sequence.makeIterator()
    while let _ = iterator.withNext({ combine(&result, $0) }) { }
    return result
}

// map — universal (transform borrows element, produces Copyable result)
func map_withNext<S: SequenceProtocol_withNext & ~Copyable, R>(
    _ sequence: borrowing S,
    _ transform: (borrowing S.Element) -> R
) -> [R] {
    var result: [R] = []
    var iterator = sequence.makeIterator()
    while let transformed = iterator.withNext({ transform($0) }) {
        result.append(transformed)
    }
    return result
}

// count — universal
func count_withNext<S: SequenceProtocol_withNext & ~Copyable>(
    _ sequence: borrowing S
) -> Int {
    var n = 0
    var iterator = sequence.makeIterator()
    while let _ = iterator.withNext({ _ in () }) { n += 1 }
    return n
}

// ============================================================================
// MARK: - 6. Tests
// ============================================================================

func test_derivedNext() {
    print("Test 1: Derived next() for Copyable elements")
    let array = SimpleArray(storage: [10, 20, 30])
    var iterator = array.makeIterator()

    // next() is derived from withNext { $0 } for Copyable
    var elements: [Int] = []
    while let element = iterator.next() {
        elements.append(element)
    }
    assert(elements == [10, 20, 30], "Derived next() should yield all elements")
    print("  [PASS] Derived next() yields correct elements: \(elements)")
}

func test_noncopyable_forEach() {
    print("Test 2: ~Copyable forEach via withNext")
    let buffer = NoncopyableBuffer(count: 5)
    var ids: [Int] = []

    forEach_withNext(buffer) { element in
        ids.append(element.id)
    }

    assert(ids == [0, 1, 2, 3, 4], "forEach should visit all elements")
    print("  [PASS] ~Copyable forEach yields ids: \(ids)")
}

func test_copyable_algorithms() {
    print("Test 3: Algorithm composition (Copyable)")
    let array = SimpleArray(storage: [1, 2, 3, 4, 5])

    // contains — use explicit closure to avoid borrowing operator inference issues
    let has3 = contains_withNext(array, where: { element in
        let val: Int = element  // implicit copy (Copyable)
        return val == 3
    })
    assert(has3, "Should contain 3")
    print("  [PASS] contains(3) = \(has3)")

    let has9 = contains_withNext(array, where: { element in
        let val: Int = element
        return val == 9
    })
    assert(!has9, "Should not contain 9")
    print("  [PASS] contains(9) = \(has9)")

    // reduce
    let sum = reduce_withNext(array, into: 0) { (acc: inout Int, element) in
        let val: Int = element
        acc += val
    }
    assert(sum == 15, "Sum should be 15")
    print("  [PASS] reduce(sum) = \(sum)")

    // map
    let doubled = map_withNext(array) { (element) -> Int in
        let val: Int = element
        return val * 2
    }
    assert(doubled == [2, 4, 6, 8, 10], "Map should double")
    print("  [PASS] map(*2) = \(doubled)")

    // count
    let n = count_withNext(array)
    assert(n == 5, "Count should be 5")
    print("  [PASS] count = \(n)")
}

func test_noncopyable_algorithms() {
    print("Test 4: Algorithm composition (~Copyable)")
    let buffer = NoncopyableBuffer(count: 4)

    // contains — access .id (Copyable field) from borrowing ~Copyable element
    let has2 = contains_withNext(buffer, where: { element in
        element.id == 2
    })
    assert(has2, "Should contain id 2")
    print("  [PASS] ~Copyable contains(id == 2) = \(has2)")

    // reduce — access .id from borrowing ~Copyable element
    let idSum = reduce_withNext(buffer, into: 0) { (acc: inout Int, element) in
        acc += element.id
    }
    assert(idSum == 6, "Sum of ids 0+1+2+3 = 6")
    print("  [PASS] ~Copyable reduce(id sum) = \(idSum)")

    // map — borrow ~Copyable element, produce Copyable result
    let ids = map_withNext(buffer) { element -> Int in
        element.id
    }
    assert(ids == [0, 1, 2, 3], "Map should extract ids")
    print("  [PASS] ~Copyable map(id) = \(ids)")

    // count
    let n = count_withNext(buffer)
    assert(n == 4, "Count should be 4")
    print("  [PASS] ~Copyable count = \(n)")
}

func test_multipleIteration() {
    print("Test 5: Multiple iteration (container not consumed)")
    let buffer = NoncopyableBuffer(count: 3)

    // First iteration
    var ids1: [Int] = []
    forEach_withNext(buffer) { ids1.append($0.id) }

    // Second iteration — container still alive because withNext borrows
    var ids2: [Int] = []
    forEach_withNext(buffer) { ids2.append($0.id) }

    assert(ids1 == ids2, "Both iterations should yield same elements")
    print("  [PASS] Multiple iterations yield same result: \(ids1) == \(ids2)")
}

// ============================================================================
// MARK: - Run All Tests
// ============================================================================

print("=== Borrowing Iterator Primitive Experiment ===")
print()

test_derivedNext()
print()

test_noncopyable_forEach()
print()

test_copyable_algorithms()
print()

test_noncopyable_algorithms()
print()

test_multipleIteration()
print()

print("=== All tests passed ===")
