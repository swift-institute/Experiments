// MARK: - Generic Method Where Clause
// Purpose: Generic where clause on method (not extension)
// Status: CONFIRMED
// Date: 2026-01-21
// Toolchain: Swift 6.2

// Tests: generic where clause constraints can be placed
// on individual methods, not just extensions.

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

print("generic-method-where-clause: CONFIRMED")
