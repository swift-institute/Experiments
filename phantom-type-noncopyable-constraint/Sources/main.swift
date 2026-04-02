// MARK: - Phantom Type ~Copyable Constraint
// Purpose: Phantom types require ~Copyable constraint
// Status: CONFIRMED
// Result: CONFIRMED — phantom type parameters must suppress Copyable to accept ~Copyable arguments; conditional Copyable on RawValue works
// Date: 2026-01-21
// Toolchain: Swift 6.2
//
// Production note: In swift-primitives, phantom-typed indices use
// Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable with conditional
// Copyable where RawValue: Copyable. Index<T> is a typealias for Tagged<T, Ordinal>.

// Phantom type parameters must suppress Copyable to work
// with ~Copyable phantom arguments.

// MARK: Variant 1 — Unconditional Copyable (simplified experiment)

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

// MARK: Variant 2 — Conditional Copyable (mirrors production Tagged)

struct ConditionalIndex<Phantom: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    let rawValue: RawValue
    init(_ rawValue: consuming RawValue) { self.rawValue = rawValue }
}

extension ConditionalIndex: Copyable where Phantom: ~Copyable, RawValue: Copyable {}

// With Copyable raw value — ConditionalIndex is Copyable
let ci1 = ConditionalIndex<Resource, Int>(99)
let ci1Copy = ci1  // Works: Int is Copyable, so ConditionalIndex is Copyable
print("ConditionalIndex (Copyable raw): \(ci1.rawValue), copy: \(ci1Copy.rawValue)")
assert(ci1.rawValue == 99)
assert(ci1Copy.rawValue == 99)

// With ~Copyable raw value — ConditionalIndex is ~Copyable
struct UniqueHandle: ~Copyable {
    let fd: Int
}

let ci2 = ConditionalIndex<Item, UniqueHandle>(UniqueHandle(fd: 3))
// let ci2Copy = ci2  // Compile error: UniqueHandle is ~Copyable, so ConditionalIndex is ~Copyable
print("ConditionalIndex (~Copyable raw): fd=\(ci2.rawValue.fd)")
assert(ci2.rawValue.fd == 3)

print("phantom-type-noncopyable-constraint: CONFIRMED")
