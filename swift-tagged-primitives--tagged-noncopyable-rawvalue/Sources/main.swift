// MARK: - Integration Test: Tagged with ~Copyable Underlying
// Purpose: Verify Tagged works with actual Equation/Comparison/Hash primitives packages
// Hypothesis: Tagged conformances from external packages work correctly
//
// Toolchain: Swift 6.2 (macOS 26)
// Result: CONFIRMED - all tests pass
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-01-24
//
// Evidence:
// - Equation.Protocol: a == b (same id): true, a == c (diff id): false
// - Comparison.Protocol: low < high: true, high > low: true
// - Hash.Protocol: hash(a) == hash(b) (same id): true
// - Copyable Underlying: Swift.Equatable/Comparable/Hashable work correctly
//
// This test uses the actual packages, not inline definitions.

import Tagged_Primitives
import Carrier_Primitives_Standard_Library_Integration
import Equation_Primitives
import Comparison_Primitives
import Hash_Primitives

// =============================================================================
// MARK: - Test Type: ~Copyable Resource
// =============================================================================

struct Resource: ~Copyable {
    let id: Int
    let priority: Int
}

// Conform to the ~Copyable-aware protocols
extension Resource: Equation.`Protocol` {
    static func == (lhs: borrowing Resource, rhs: borrowing Resource) -> Bool {
        lhs.id == rhs.id
    }
}

extension Resource: Comparison.`Protocol` {
    static func < (lhs: borrowing Resource, rhs: borrowing Resource) -> Bool {
        lhs.priority < rhs.priority
    }
}

extension Resource: Hash.`Protocol` {
    borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// =============================================================================
// MARK: - Tag Types
// =============================================================================

enum ResourceTag {}

// =============================================================================
// MARK: - Tests
// =============================================================================

func testEquation() {
    print("Testing Equation.Protocol conformance...")

    let a = Tagged<ResourceTag, Resource>(Resource(id: 1, priority: 10))
    let b = Tagged<ResourceTag, Resource>(Resource(id: 1, priority: 20))
    let c = Tagged<ResourceTag, Resource>(Resource(id: 2, priority: 10))

    // a and b have same id, so should be equal
    print("  a == b (same id): \(a == b)")  // Expected: true
    // a and c have different id, so should not be equal
    print("  a == c (diff id): \(a == c)")  // Expected: false
}

func testComparison() {
    print("Testing Comparison.Protocol conformance...")

    let low = Tagged<ResourceTag, Resource>(Resource(id: 1, priority: 10))
    let high = Tagged<ResourceTag, Resource>(Resource(id: 2, priority: 100))

    print("  low < high: \(low < high)")    // Expected: true
    print("  high > low: \(high > low)")    // Expected: true
    print("  low <= low: \(low <= low)")    // Expected: true
}

func testHash() {
    print("Testing Hash.Protocol conformance...")

    let a = Tagged<ResourceTag, Resource>(Resource(id: 42, priority: 1))
    let b = Tagged<ResourceTag, Resource>(Resource(id: 42, priority: 99))

    // Same id should produce same hash
    let hashA = a.hashValue
    let hashB = b.hashValue
    print("  hash(a) == hash(b) (same id): \(hashA == hashB)")  // Expected: true
}

func testCopyableRawValue() {
    print("Testing with Copyable Underlying (Int)...")

    // Standard library conformances should still work
    let x = Tagged<ResourceTag, Int>(42)
    let y = Tagged<ResourceTag, Int>(42)
    let z = Tagged<ResourceTag, Int>(99)

    // Uses Swift.Equatable
    print("  x == y: \(x == y)")  // Expected: true
    print("  x == z: \(x == z)")  // Expected: false

    // Uses Swift.Comparable
    print("  x < z: \(x < z)")    // Expected: true

    // Uses Swift.Hashable
    print("  hash(x) == hash(y): \(x.hashValue == y.hashValue)")  // Expected: true
}

// =============================================================================
// MARK: - Execution
// =============================================================================

print("=== Tagged ~Copyable Integration Test ===")
print("")
testEquation()
print("")
testComparison()
print("")
testHash()
print("")
testCopyableRawValue()
print("")
print("=== All tests complete ===")
