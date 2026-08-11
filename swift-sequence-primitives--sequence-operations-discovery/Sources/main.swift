// MARK: - Sequence Operations Test
// Purpose: Test all sequence operations with ~Copyable containers
//
// Operations tested:
// - .satisfies.all { }, .satisfies.any { }, .satisfies.none { }
// - .contains { }
// - .first { }
// - .reduce.into(_:) { }, .reduce.from(_:) { }
// - .map { }
// - .filter { }
// - .count, .count(where:)
//
// Toolchain: Apple Swift version 6.2.3
// Status: SUPERSEDED 2026-04-30 — Sequence protocol restructured (Sequence.Protocol, Sequence.Borrowing.Protocol, Sequence.Iterator.Protocol, Sequence.Drain.Protocol, etc.); experiment tests an earlier non-decomposed Sequence surface and would require redesign against current ForEach/Drain witness shape
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Date: 2026-01-22

import Sequence_Primitives
import Property_Primitives

// MARK: - Test Container

struct NCContainer<Element>: ~Copyable {
    var storage: [Element]

    init(_ elements: [Element]) {
        self.storage = elements
    }

    deinit {
        print("  [deinit] NCContainer with \(storage.count) elements")
    }
}

// MARK: - Sequence.Protocol Conformance

extension NCContainer: Sequence.`Protocol` {
    func makeIterator() -> Array<Element>.Iterator {
        storage.makeIterator()
    }
}

// MARK: - Property Accessors

extension NCContainer {
    var satisfies: Property<Sequence.Satisfies, NCContainer>.View {
        mutating _read {
            yield unsafe Property<Sequence.Satisfies, NCContainer>.View(&self)
        }
    }

    var contains: Property<Sequence.Contains, NCContainer>.View {
        mutating _read {
            yield unsafe Property<Sequence.Contains, NCContainer>.View(&self)
        }
    }

    var first: Property<Sequence.First, NCContainer>.View {
        mutating _read {
            yield unsafe Property<Sequence.First, NCContainer>.View(&self)
        }
    }

    var reduce: Property<Sequence.Reduce, NCContainer>.View {
        mutating _read {
            yield unsafe Property<Sequence.Reduce, NCContainer>.View(&self)
        }
    }

    var map: Property<Sequence.Map, NCContainer>.View {
        mutating _read {
            yield unsafe Property<Sequence.Map, NCContainer>.View(&self)
        }
    }

    var filter: Property<Sequence.Filter, NCContainer>.View {
        mutating _read {
            yield unsafe Property<Sequence.Filter, NCContainer>.View(&self)
        }
    }

    var count: Property<Sequence.Count, NCContainer>.View {
        mutating _read {
            yield unsafe Property<Sequence.Count, NCContainer>.View(&self)
        }
    }
}

// MARK: - Tests

print()
print("=== Sequence Operations Test ===")
print()
print("Testing sequence operations from sequence-primitives")
print("on ~Copyable containers")
print()

// Test: satisfies.all, satisfies.any, satisfies.none
func testSatisfies() {
    print("=== satisfies.all/any/none ===")
    do {
        var container = NCContainer([2, 4, 6, 8])
        let allEven = container.satisfies.all { $0 % 2 == 0 }
        let anyOdd = container.satisfies.any { $0 % 2 != 0 }
        let noneNegative = container.satisfies.none { $0 < 0 }
        print("  [2,4,6,8].satisfies.all { even }: \(allEven)")
        print("  [2,4,6,8].satisfies.any { odd }: \(anyOdd)")
        print("  [2,4,6,8].satisfies.none { < 0 }: \(noneNegative)")
        print("  Result: \(allEven && !anyOdd && noneNegative ? "PASS" : "FAIL")")
    }
    print()
}

// Test: contains { }
func testContains() {
    print("=== contains { } ===")
    do {
        var container = NCContainer([1, 2, 3, 4, 5])
        let hasThree = container.contains { $0 == 3 }
        let hasTen = container.contains { $0 == 10 }
        print("  [1,2,3,4,5].contains { == 3 }: \(hasThree)")
        print("  [1,2,3,4,5].contains { == 10 }: \(hasTen)")
        print("  Result: \(hasThree && !hasTen ? "PASS" : "FAIL")")
    }
    print()
}

// Test: first { }
func testFirst() {
    print("=== first { } ===")
    do {
        var container = NCContainer([1, 2, 3, 4, 5])
        let firstEven = container.first { $0 % 2 == 0 }
        let firstTen = container.first { $0 > 10 }
        print("  [1,2,3,4,5].first { even }: \(firstEven as Any)")
        print("  [1,2,3,4,5].first { > 10 }: \(firstTen as Any)")
        print("  Result: \(firstEven == 2 && firstTen == nil ? "PASS" : "FAIL")")
    }
    print()
}

// Test: reduce.into, reduce.from
func testReduce() {
    print("=== reduce.into/from ===")
    do {
        var container = NCContainer([1, 2, 3, 4, 5])
        let sum = container.reduce.into(0) { $0 += $1 }
        let product = container.reduce.from(1) { $0 * $1 }
        print("  [1,2,3,4,5].reduce.into(0) { += }: \(sum)")
        print("  [1,2,3,4,5].reduce.from(1) { * }: \(product)")
        print("  Result: \(sum == 15 && product == 120 ? "PASS" : "FAIL")")
    }
    print()
}

// Test: map { }
func testMap() {
    print("=== map { } ===")
    do {
        var container = NCContainer([1, 2, 3])
        let doubled = container.map { $0 * 2 }
        let strings = container.map { "item-\($0)" }
        print("  [1,2,3].map { * 2 }: \(doubled)")
        print("  [1,2,3].map { string }: \(strings)")
        print("  Result: \(doubled == [2, 4, 6] ? "PASS" : "FAIL")")
    }
    print()
}

// Test: filter { }
func testFilter() {
    print("=== filter { } ===")
    do {
        var container = NCContainer([1, 2, 3, 4, 5, 6])
        let evens = container.filter { $0 % 2 == 0 }
        print("  [1,2,3,4,5,6].filter { even }: \(evens)")
        print("  Result: \(evens == [2, 4, 6] ? "PASS" : "FAIL")")
    }
    print()
}

// Test: count, count(where:)
func testCount() {
    print("=== count / count(where:) ===")
    do {
        var container = NCContainer([1, 2, 3, 4, 5, 6])
        let evenCount = container.count { $0 % 2 == 0 }
        let totalCount = container.count
        print("  [1,2,3,4,5,6].count { even }: \(evenCount)")
        print("  [1,2,3,4,5,6].count: \(totalCount)")
        print("  Result: \(evenCount == 3 && totalCount == 6 ? "PASS" : "FAIL")")
    }
    print()
}

// MARK: - Run Tests

testSatisfies()
testContains()
testFirst()
testReduce()
testMap()
testFilter()
testCount()

print("=== All Tests Complete ===")
