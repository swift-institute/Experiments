// MARK: - Sequence.Protocol ForEach Test
// Purpose: Verify Sequence.Protocol and Property.View extensions work
//
// Tests:
// [TEST-1] ~Copyable type can conform to Sequence.Protocol
// [TEST-2] .forEach { } borrowing iteration works
// [TEST-3] .forEach.borrowing { } explicit borrowing works
// [TEST-4] ~Copyable type can conform to Sequence.Clearable
// [TEST-5] .forEach.consuming { } consuming iteration works
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

// MARK: - Sequence.Clearable Conformance

extension NCContainer: Sequence.Clearable {
    mutating func removeAll() {
        storage.removeAll()
    }
}

// MARK: - ForEach Property

extension NCContainer {
    var forEach: Property<Sequence.ForEach, NCContainer>.View {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, NCContainer>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, NCContainer>.View(&self)
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

// MARK: - Run

print()
print("=== Sequence.Protocol ForEach Test ===")
print()
print("Testing Sequence.Protocol and Property.View extensions")
print("from sequence-primitives package.")
print()

testBorrowing()
testBorrowingExplicit()
testConsuming()

print("=== All Tests Complete ===")
