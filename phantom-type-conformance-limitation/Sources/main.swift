// MARK: - Phantom Type Conformance Limitation
// Purpose: Cannot have multiple conditional conformances to same protocol
// Status: CONFIRMED
// Date: 2026-01-21
// Toolchain: Swift 6.2
//
// Production reference: Tagged.swift uses `where Tag: ~Copyable` on
// both Equatable and Comparable, proving they work with ~Copyable phantoms.
// The actual limitation is: you cannot have TWO conditional conformances
// to the SAME protocol with different constraints.

struct TypedIndex<Phantom: ~Copyable>: Copyable {
    let rawValue: Int
    init(_ rawValue: Int) { self.rawValue = rawValue }
}

// Equatable works with ~Copyable phantoms
extension TypedIndex: Equatable where Phantom: ~Copyable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

// Comparable ALSO works with ~Copyable phantoms
// (The original experiment incorrectly claimed this was impossible.)
extension TypedIndex: Comparable where Phantom: ~Copyable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct Resource: ~Copyable { var id: Int }
struct Bucket: ~Copyable {}

// Both work with ~Copyable phantom types
let a = TypedIndex<Resource>(1)
let b = TypedIndex<Resource>(5)
assert(a < b)
assert(a == a)

let c = TypedIndex<Bucket>(3)
let d = TypedIndex<Bucket>(7)
assert(c < d)
assert(c == c)

print("Comparable with ~Copyable phantom: \(a < b)")
print("Equatable with ~Copyable phantom: \(c == c)")

// THE ACTUAL LIMITATION: Cannot have multiple conditional conformances
// to the SAME protocol with different constraints.
//
// extension TypedIndex: CustomStringConvertible where Phantom: Hashable {
//     var description: String { "hashable-\(rawValue)" }
// }
// extension TypedIndex: CustomStringConvertible where Phantom: Comparable {
//     var description: String { "comparable-\(rawValue)" }
// }
// Error: Conflicting conformance of 'TypedIndex<Phantom>' to 'CustomStringConvertible'
//
// A single conformance must cover all phantom types — you cannot
// specialize protocol behavior per phantom constraint.

print("phantom-type-conformance-limitation: CONFIRMED")
