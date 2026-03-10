// MARK: - Generic Method Where Clause
// Purpose: Generic where clause on method (not extension)
// Status: CONFIRMED
// Date: 2026-01-21
// Toolchain: Swift 6.2
//
// Production pattern: Sequence iterator types use method-level where clauses
// to provide next() -> Element? only when Element: Copyable (since Optional
// requires Copyable). For ~Copyable elements, Span-based iteration is used.

// Tests: generic where clause constraints can be placed
// on individual methods, not just extensions.

// MARK: Variant 1 — Basic method-level where clauses

struct Container<Element: ~Copyable>: ~Copyable {
    var count: Int = 0

    // Method-level where clause — works for Copyable-only operations
    func sorted() -> [Element] where Element: Copyable & Comparable {
        // placeholder — proves the signature compiles
        []
    }

    // Available for ALL elements (including ~Copyable)
    func isEmpty() -> Bool {
        count == 0
    }

    // Method-level where clause with protocol constraint
    func description() -> String where Element: CustomStringConvertible & Copyable {
        "Container with \(count) elements"
    }
}

// Test with Copyable + Comparable
var intContainer = Container<Int>(count: 5)
let empty = intContainer.isEmpty()
let _ = intContainer.sorted()
let desc = intContainer.description()

print("isEmpty: \(empty)")
print("description: \(desc)")
assert(empty == false)

// Test with ~Copyable — only isEmpty() available
struct Resource: ~Copyable { var id: Int }
var resContainer = Container<Resource>(count: 3)
let resEmpty = resContainer.isEmpty()
print("Resource isEmpty: \(resEmpty)")
assert(resEmpty == false)

// sorted() and description() are NOT available for Container<Resource>
// Uncommenting would produce compile error:
// resContainer.sorted()  // Error: ~Copyable does not conform to Comparable

// MARK: Variant 2 — Production pattern: Iterator with conditional next()

struct Iterator<Element: ~Copyable>: ~Copyable {
    var index: Int = 0
    let count: Int

    // Only available when Element is Copyable (Optional requires it)
    mutating func next() -> Int? where Element: Copyable {
        guard index < count else { return nil }
        defer { index += 1 }
        return index
    }

    // Available for all Element types (including ~Copyable)
    var hasNext: Bool { index < count }
}

// Test Iterator with Copyable Element — next() is available
var iter = Iterator<Int>(count: 3)
assert(iter.hasNext)
assert(iter.next() == 0)
assert(iter.next() == 1)
assert(iter.next() == 2)
assert(iter.next() == nil)
assert(!iter.hasNext)
print("Iterator (Copyable): exhausted after 3 elements")

// Test Iterator with ~Copyable Element — only hasNext is available
var resIter = Iterator<Resource>(count: 2)
assert(resIter.hasNext)
// resIter.next()  // Compile error: Resource does not conform to Copyable
print("Iterator (~Copyable): hasNext = \(resIter.hasNext)")

print("generic-method-where-clause: CONFIRMED")
