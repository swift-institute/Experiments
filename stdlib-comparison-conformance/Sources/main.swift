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
//
// Production naming: Comparison.`Protocol` (using backtick escaping)
// Production hierarchy: Equation.Protocol → Comparison.Protocol → Hash.Protocol
// All support ~Copyable via `protocol `Protocol`: ~Copyable { ... }`

// Track 1: Custom protocols that support ~Copyable

/// Matches production Equation.`Protocol`
/// Core operation: == (equality check)
/// For ~Copyable types, != is derived here. For Copyable types that also
/// conform to Equatable, stdlib provides != to avoid ambiguity.
protocol EquationProtocol: ~Copyable {
    static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool
}

/// Matches production Comparison.`Protocol` (refines Equation.Protocol)
/// Core operation: < (strict ordering)
/// For ~Copyable types, >, <=, >= are derived here. For Copyable types that
/// also conform to Comparable, stdlib provides the derived operators.
protocol ComparisonProtocol: EquationProtocol, ~Copyable {
    static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool
}

// Typed index — supports ~Copyable phantoms
struct TypedIndex<Phantom: ~Copyable>: Copyable {
    let rawValue: Int
    init(_ rawValue: Int) { self.rawValue = rawValue }
}

// Track 1: Custom comparison (always available, including ~Copyable phantoms)
extension TypedIndex: EquationProtocol where Phantom: ~Copyable {
    static func == (lhs: borrowing TypedIndex, rhs: borrowing TypedIndex) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

extension TypedIndex: ComparisonProtocol where Phantom: ~Copyable {
    static func < (lhs: borrowing TypedIndex, rhs: borrowing TypedIndex) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// Track 2: stdlib Comparable (bridge, always available since TypedIndex is Copyable)
// The == and < from Track 1 satisfy Equatable and Comparable requirements.
// stdlib provides the derived operators (!=, >, <=, >=) without ambiguity.
extension TypedIndex: Equatable where Phantom: ~Copyable {}

extension TypedIndex: Comparable where Phantom: ~Copyable {}

// Test with ~Copyable phantom
struct Resource: ~Copyable { var id: Int }

let a = TypedIndex<Resource>(1)
let b = TypedIndex<Resource>(5)

// Core operations from Track 1 (EquationProtocol + ComparisonProtocol)
assert(a == a)
assert(a < b)

// Derived operations from stdlib Track 2 (Equatable + Comparable)
assert(a != b)
assert(b > a)
assert(a <= b)
assert(b >= a)

// stdlib sorting works (TypedIndex is Copyable)
let sorted = [b, a].sorted()
assert(sorted[0].rawValue == 1)

print("Custom ==: \(a == a)")
print("Custom <: \(a < b)")
print("Stdlib !=: \(a != b)")
print("Stdlib sorted: \(sorted.map { $0.rawValue })")
print("stdlib-comparison-conformance: COMPLETE")
