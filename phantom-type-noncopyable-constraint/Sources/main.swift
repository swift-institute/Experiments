// MARK: - Phantom Type ~Copyable Constraint
// Purpose: Phantom types require ~Copyable constraint
// Status: CONFIRMED
// Date: 2026-01-21
// Toolchain: Swift 6.2

// Phantom type parameters must suppress Copyable to work
// with ~Copyable phantom arguments.

// CORRECT: Phantom parameter suppresses Copyable
struct TypedIndex<Phantom: ~Copyable>: Copyable {
    let rawValue: Int
    init(_ rawValue: Int) { self.rawValue = rawValue }
}

// ~Copyable type used as phantom
struct Resource: ~Copyable {
    var id: Int
}

// Copyable type used as phantom
struct Item {
    var name: String
}

// Both work because phantom suppresses Copyable
let resourceIdx = TypedIndex<Resource>(42)
let itemIdx = TypedIndex<Item>(7)

// Type safety: these are different types
func acceptResourceIndex(_ idx: TypedIndex<Resource>) -> Int { idx.rawValue }
func acceptItemIndex(_ idx: TypedIndex<Item>) -> Int { idx.rawValue }

let r = acceptResourceIndex(resourceIdx)
let i = acceptItemIndex(itemIdx)
// acceptResourceIndex(itemIdx)  // Compile error — type safety

print("Resource index: \(r)")
print("Item index: \(i)")
assert(r == 42)
assert(i == 7)

// TypedIndex itself IS Copyable regardless of phantom
let copy = resourceIdx
print("Copied index: \(copy.rawValue)")
assert(copy.rawValue == 42)

print("phantom-type-noncopyable-constraint: CONFIRMED")
