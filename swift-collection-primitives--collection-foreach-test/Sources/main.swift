// MARK: - Collection.Protocol ForEach Test
// Purpose: Verify Collection.Protocol and Property.View extensions work
//
// Tests:
// [TEST-1] ~Copyable type can conform to Collection.Protocol
// [TEST-2] .forEach { } borrowing iteration works
// [TEST-3] .forEach.borrowing { } explicit borrowing works
// [TEST-4] ~Copyable type can conform to Collection.Clearable
// [TEST-5] .forEach.consuming { } consuming iteration works
//
// Toolchain: Apple Swift version 6.2.3
// Status: SUPERSEDED 2026-04-30 — Collection.`Protocol` conformance surface changed; experiment NCContainer no longer conforms
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Date: 2026-01-22

import Collection_Primitives
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

// MARK: - Collection.Protocol Conformance

extension NCContainer: Collection.`Protocol` {
    typealias Index = Int

    var startIndex: Int { 0 }
    var endIndex: Int { storage.count }

    subscript(position: Int) -> Element {
        storage[position]
    }

    func index(after i: Int) -> Int {
        i + 1
    }

    func makeIterator() -> Array<Element>.Iterator {
        storage.makeIterator()
    }
}

// MARK: - Collection.Clearable Conformance

extension NCContainer: Collection.Clearable {
    mutating func removeAll() {
        storage.removeAll()
    }
}

// MARK: - ForEach Property

extension NCContainer {
    var forEach: Property<Collection.ForEach, NCContainer>.View {
        mutating _read {
            yield unsafe Property<Collection.ForEach, NCContainer>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Collection.ForEach, NCContainer>.View(&self)
            yield &view
        }
    }
}

// MARK: - Tests

func testBorrowing() {
    print("=== TEST-2: .forEach { } borrowing ===")
    do {
        var container = NCContainer([1, 2, 3])
        container.forEach { print("  Element: \($0)") }
        print("  After: \(container.storage.count) elements")
        print("  Result: \(container.storage.count == 3 ? "PASS" : "FAIL")")
    }
    print()
}

func testBorrowingExplicit() {
    print("=== TEST-3: .forEach.borrowing { } ===")
    do {
        var container = NCContainer(["a", "b", "c"])
        container.forEach.borrowing { print("  Element: \($0)") }
        print("  After: \(container.storage.count) elements")
        print("  Result: \(container.storage.count == 3 ? "PASS" : "FAIL")")
    }
    print()
}

func testConsuming() {
    print("=== TEST-5: .forEach.consuming { } ===")
    do {
        var container = NCContainer([10, 20, 30])
        container.forEach.consuming { print("  Element: \($0)") }
        print("  After: \(container.storage.count) elements")
        print("  Result: \(container.storage.isEmpty ? "PASS - CONSUMED" : "FAIL")")
    }
    print()
}

func testIndexAccess() {
    print("=== TEST-6: Index-based access ===")
    do {
        var container = NCContainer([100, 200, 300])
        print("  startIndex: \(container.startIndex)")
        print("  endIndex: \(container.endIndex)")
        print("  Element at 0: \(container[0])")
        print("  Element at 1: \(container[1])")
        print("  Element at 2: \(container[2])")
        print("  Result: PASS")
    }
    print()
}

// MARK: - Run

print()
print("=== Collection.Protocol ForEach Test ===")
print()
print("Testing Collection.Protocol and Property.View extensions")
print("from collection-primitives package.")
print()

testBorrowing()
testBorrowingExplicit()
testConsuming()
testIndexAccess()

print("=== All Tests Complete ===")
