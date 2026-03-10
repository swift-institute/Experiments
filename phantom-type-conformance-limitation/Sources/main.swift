// MARK: - Phantom Type Conformance Limitation
// Purpose: Cannot have multiple conformances with different constraints
// Status: CONFIRMED
// Date: 2026-01-21
// Toolchain: Swift 6.2

// Swift prevents multiple conditional conformances to the same protocol.
// This means phantom-typed indices cannot have different comparison
// behaviors for different phantom types.

struct TypedIndex<Phantom: ~Copyable>: Copyable {
    let rawValue: Int
    init(_ rawValue: Int) { self.rawValue = rawValue }
}

// Conformance for Equatable — works unconditionally since TypedIndex is Copyable
// and only uses rawValue (not Phantom).
// However, the extension implicitly requires Phantom: Copyable because
// protocol conformance extensions inherit the default Copyable constraint.
extension TypedIndex: Equatable where Phantom: ~Copyable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

// Comparable requires Phantom: Copyable (implicit).
// We CANNOT write: extension TypedIndex: Comparable where Phantom: ~Copyable
// because Comparable refines Equatable which refines Copyable-conforming Self.
extension TypedIndex: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// Problem: We CANNOT add a second, differently-constrained conformance:
// extension TypedIndex: CustomStringConvertible where Phantom: Hashable {
//     var description: String { "hashable-\(rawValue)" }
// }
// extension TypedIndex: CustomStringConvertible where Phantom: Comparable {
//     var description: String { "comparable-\(rawValue)" }
// }
// Error: Conflicting conformance of 'TypedIndex<Phantom>' to protocol 'CustomStringConvertible'

// The conformance applies universally for all Phantom types — you cannot
// specialize behavior per phantom constraint.

struct Element { var id: Int }
struct Bucket: ~Copyable {}

let elemIdx = TypedIndex<Element>(3)
let bucketIdx = TypedIndex<Bucket>(5)

// Equatable works for both (including ~Copyable phantom) because we
// added the `where Phantom: ~Copyable` constraint on the extension.
assert(TypedIndex<Element>(1) == TypedIndex<Element>(1))
assert(TypedIndex<Bucket>(1) == TypedIndex<Bucket>(1))

// Comparable only works for Copyable phantoms
assert(TypedIndex<Element>(1) < TypedIndex<Element>(2))
// TypedIndex<Bucket>(1) < TypedIndex<Bucket>(2)  // Error: requires Bucket conform to Copyable

// This demonstrates the limitation: conformances to protocols that
// don't suppress Copyable cannot be used with ~Copyable phantoms,
// and you cannot have multiple conditional conformances to the same protocol.

print("Element index comparison: \(elemIdx < TypedIndex<Element>(10))")
print("Bucket index equality: \(bucketIdx == TypedIndex<Bucket>(5))")
print("phantom-type-conformance-limitation: CONFIRMED")
