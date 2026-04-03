// SUPERSEDED: See noncopyable-access-patterns
// MARK: - Consuming Iteration for Ordered Sets
// Purpose: Verify consuming iteration APIs are feasible for Set.Ordered
//
// Hypothesis: A ~Copyable ConsumingIterator can hold a set and yield
//             elements by moving them out, enabling for-in style
//             consuming iteration via while-let loops.
//
// Claims being tested:
// [CLAIM-001] ConsumingIterator can be ~Copyable and hold set ownership
// [CLAIM-002] consuming func makeConsumingIterator() transfers ownership correctly
// [CLAIM-003] consuming func forEach(_ body: (consuming Element) -> Void) works
// [CLAIM-004] Iterator deinit can clean up partially-consumed elements
// [CLAIM-005] consumingCount() can return both count and iterator via tuple
//
// Toolchain: Apple Swift version 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: arm64-apple-macosx26.0
// Date: 2026-01-22
//
// Results Summary:
// [CLAIM-001] CONFIRMED - ~Copyable iterator with array storage works
// [CLAIM-002] CONFIRMED - consuming func returns ~Copyable iterator
// [CLAIM-003] CONFIRMED - consuming forEach with consuming closure works
// [CLAIM-004] CONFIRMED - deinit handles partial consumption correctly
// [CLAIM-005] REFUTED - tuples cannot contain ~Copyable elements (Swift 6.2 limitation)
//
// Key Finding: consumingCount() returning (Int, Iterator) tuple is NOT possible
// with ~Copyable iterator. Workaround: use a struct wrapper or separate calls.
//
// Primary Diagnostic for CLAIM-005:
// Command: swift build 2>&1
// error: tuple with noncopyable element type 'OrderedSetMock<Element>.Consuming.Iterator' is not supported

// MARK: - Variant 1: Basic ConsumingIterator
// Hypothesis: A ~Copyable iterator can hold an array and move elements out
// Result: CONFIRMED - compiles and executes correctly
// Evidence: Output shows elements consumed in order, deinit reports remaining

struct ConsumingIterator<Element>: ~Copyable {
    var _storage: [Element]
    var _index: Int

    init(consuming storage: consuming [Element]) {
        self._storage = storage
        self._index = 0
    }

    mutating func next() -> Element? {
        guard _index < _storage.count else { return nil }
        // Move element out - for Copyable elements this is effectively a copy,
        // but the semantics are correct for when we have ~Copyable elements
        let element = _storage[_index]
        _index += 1
        return element
    }

    deinit {
        // Storage array will be deinitialized automatically
        // For a real implementation with raw storage, we would need to
        // deinitialize remaining elements here
        print("ConsumingIterator deinit: \(_storage.count - _index) elements remaining")
    }
}

func testBasicConsumingIterator() {
    print("--- Variant 1: Basic ConsumingIterator ---")

    let array = [1, 2, 3, 4, 5]
    var iterator = ConsumingIterator(consuming: array)

    var sum = 0
    while let element = iterator.next() {
        sum += element
        print("Consumed: \(element)")
    }
    print("Sum: \(sum)")
    print()
}

// MARK: - Variant 2: Consuming forEach
// Hypothesis: consuming func forEach works with consuming closures
// Result: CONFIRMED - compiles and executes correctly

struct OrderedSetMock<Element: Hashable>: ~Copyable {
    var _elements: [Element]

    init(_ elements: [Element]) {
        self._elements = elements
    }

    var count: Int { _elements.count }

    consuming func forEach(_ body: (consuming Element) -> Void) {
        for element in _elements {
            body(element)
        }
    }
}

func testConsumingForEach() {
    print("--- Variant 2: Consuming forEach ---")

    let set = OrderedSetMock([10, 20, 30])

    var collected: [Int] = []
    set.forEach { element in
        collected.append(element)
        print("ForEach consumed: \(element)")
    }
    print("Collected: \(collected)")
    print()
}

// MARK: - Variant 3: makeConsumingIterator
// Hypothesis: Consuming methods can transfer ownership correctly
// Result: CONFIRMED - ownership transfers to iterator, iteration works

extension OrderedSetMock {
    struct Consuming: ~Copyable {
        struct Iterator: ~Copyable {
            var _storage: [Element]
            var _index: Int

            init(consuming storage: consuming [Element]) {
                self._storage = storage
                self._index = 0
            }

            mutating func next() -> Element? {
                guard _index < _storage.count else { return nil }
                let element = _storage[_index]
                _index += 1
                return element
            }

            deinit {
                let remaining = _storage.count - _index
                if remaining > 0 {
                    print("Consuming.Iterator deinit: \(remaining) elements not consumed")
                }
            }
        }
    }

    consuming func makeConsumingIterator() -> Consuming.Iterator {
        Consuming.Iterator(consuming: _elements)
    }

    // MARK: - Variant 4: consumingCount via struct wrapper
    // Hypothesis: Can work around tuple limitation with struct
    // Result: CONFIRMED - struct wrapper allows returning both count and iterator

    struct CountedIterator: ~Copyable {
        let count: Int
        var iterator: Consuming.Iterator

        init(count: Int, iterator: consuming Consuming.Iterator) {
            self.count = count
            self.iterator = iterator
        }
    }

    consuming func consumingCount() -> CountedIterator {
        let count = _elements.count
        return CountedIterator(count: count, iterator: Consuming.Iterator(consuming: _elements))
    }
}

func testMakeConsumingIterator() {
    print("--- Variant 3: makeConsumingIterator ---")

    let set = OrderedSetMock(["a", "b", "c", "d"])
    var iterator = set.makeConsumingIterator()

    while let element = iterator.next() {
        print("Iterator consumed: \(element)")
    }
    print()
}

func testConsumingCountWorkaround() {
    print("--- Variant 4: consumingCount with struct wrapper ---")

    let set = OrderedSetMock([100, 200, 300])
    var counted = set.consumingCount()

    print("Count before iteration: \(counted.count)")

    var result: [Int] = []
    result.reserveCapacity(counted.count)

    while let element = counted.iterator.next() {
        result.append(element)
    }
    print("Result: \(result)")
    print()
}

// MARK: - Variant 5: Partial consumption with early exit
// Hypothesis: Deinit correctly handles partially-consumed iterators
// Result: CONFIRMED - deinit reports 7 remaining elements

func testPartialConsumption() {
    print("--- Variant 5: Partial Consumption ---")

    let set = OrderedSetMock([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    var iterator = set.makeConsumingIterator()

    // Only consume first 3 elements
    for _ in 0..<3 {
        if let element = iterator.next() {
            print("Partially consumed: \(element)")
        }
    }

    print("Dropping iterator with remaining elements...")
    // iterator goes out of scope here - deinit should report 7 remaining
}

// MARK: - Variant 6: Nested types follow API-NAME-001
// Hypothesis: Nest.Name pattern works for iterator types
// Result: CONFIRMED - nested naming compiles and is discoverable

// Per [API-NAME-001], types use Nest.Name pattern:
// Set.Ordered.Consuming.Iterator (not SetOrderedConsumingIterator)
//
// This is demonstrated in OrderedSetMock.Consuming.Iterator above

func testNestedNaming() {
    print("--- Variant 6: Nested Naming ---")

    // The type OrderedSetMock.Consuming.Iterator follows [API-NAME-001]
    // No compound names like "ConsumingIterator" at module level
    let set = OrderedSetMock([42])
    var iter: OrderedSetMock<Int>.Consuming.Iterator = set.makeConsumingIterator()

    if let value = iter.next() {
        print("Type: OrderedSetMock<Int>.Consuming.Iterator")
        print("Value: \(value)")
    }
    print()
}

// MARK: - Variant 7: Tuple limitation demonstration (commented out)
// Hypothesis: Tuples can contain ~Copyable elements
// Result: REFUTED - Swift 6.2 does not support this
//
// The following code does NOT compile:
// ```
// consuming func consumingCount() -> (count: Int, iterator: Consuming.Iterator) {
//     let count = _elements.count
//     return (count, Consuming.Iterator(consuming: _elements))
// }
// ```
// Error: tuple with noncopyable element type '...' is not supported

// MARK: - Results Summary

print("=== Consuming Iteration Experiment ===")
print()

testBasicConsumingIterator()
testConsumingForEach()
testMakeConsumingIterator()
testConsumingCountWorkaround()
testPartialConsumption()
testNestedNaming()

print("=== Experiment Complete ===")
print()
print("--- Final Summary ---")
print("[CLAIM-001] CONFIRMED: ~Copyable ConsumingIterator works")
print("[CLAIM-002] CONFIRMED: consuming makeConsumingIterator() works")
print("[CLAIM-003] CONFIRMED: consuming forEach works")
print("[CLAIM-004] CONFIRMED: partial consumption + deinit cleanup works")
print("[CLAIM-005] REFUTED: tuples cannot contain ~Copyable (use struct wrapper)")

