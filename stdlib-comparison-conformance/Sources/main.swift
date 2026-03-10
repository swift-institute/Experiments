// MARK: - Stdlib Comparison Conformance
// Purpose: Dual-track architecture for stdlib Comparable integration
// Status: COMPLETE
// Date: 2026-01-22
// Toolchain: Swift 6.0

// Problem: stdlib's Comparable requires Copyable.
// ~Copyable types cannot conform to Comparable.
//
// Solution: Dual-track architecture:
// Track 1: Custom comparison protocol (works with ~Copyable)
// Track 2: Stdlib Comparable conformance (only when Copyable)

// Track 1: Custom protocol that supports ~Copyable
protocol Ordered: ~Copyable {
    static func isLessThan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
}

extension Ordered where Self: ~Copyable {
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        !isLessThan(lhs, rhs) && !isLessThan(rhs, lhs)
    }
}

// Typed index — supports ~Copyable phantoms
struct TypedIndex<Phantom: ~Copyable>: Copyable {
    let rawValue: Int
    init(_ rawValue: Int) { self.rawValue = rawValue }
}

// Track 1: Custom comparison (always available, including ~Copyable phantoms)
extension TypedIndex: Ordered where Phantom: ~Copyable {
    static func isLessThan(_ lhs: borrowing TypedIndex, _ rhs: borrowing TypedIndex) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// Track 2: stdlib Comparable (bridge, always available since TypedIndex is Copyable)
extension TypedIndex: Equatable where Phantom: ~Copyable {
    static func == (lhs: TypedIndex, rhs: TypedIndex) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

extension TypedIndex: Comparable where Phantom: ~Copyable {
    static func < (lhs: TypedIndex, rhs: TypedIndex) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// Test with ~Copyable phantom
struct Resource: ~Copyable { var id: Int }

let a = TypedIndex<Resource>(1)
let b = TypedIndex<Resource>(5)

// Custom comparison works
assert(TypedIndex<Resource>.isLessThan(a, b))
assert(!TypedIndex<Resource>.isEqual(a, b))

// stdlib Comparable also works (TypedIndex is Copyable)
assert(a < b)
assert(a != b)
let sorted = [b, a].sorted()
assert(sorted[0].rawValue == 1)

print("Custom isLessThan: \(TypedIndex<Resource>.isLessThan(a, b))")
print("Stdlib sorted: \(sorted.map { $0.rawValue })")
print("stdlib-comparison-conformance: COMPLETE")
