// MARK: - Variant 2: Algebra Layer (AlgebraExtension imported)
// Purpose: Verify that (a) Vector.one works via protocol extension, and
//          (b) Ordinal(.one) STILL resolves to Cardinal.one (non-throwing)
//          even when Vector.one is in scope via protocol extension
// Hypothesis: Protocol extension members have lower priority than direct members
//             in Swift overload resolution. Cardinal.one (direct) wins over
//             Vector.one (protocol extension), so Ordinal(.one) remains non-throwing.
//
// Toolchain: swift-6.2-DEVELOPMENT-SNAPSHOT (Xcode 26 beta)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Vector.one works, AND Ordinal(.one) resolves to Cardinal.one
//         (non-throwing) even with AlgebraExtension imported. Best of all worlds.
// Date: 2026-02-11

import BaseTypes
import AlgebraExtension

// MARK: - Test: Vector.one works via protocol extension
// Result: CONFIRMED — Vector.one = Vector(1)
func testVectorOne() {
    let v = Vector.one
    print("Vector.one = Vector(\(v.rawValue))")
    assert(v.rawValue == 1, "Expected 1")
}

// MARK: - Test: Cardinal.one still works
// Result: CONFIRMED — Cardinal.one = Cardinal(1)
func testCardinalOne() {
    let c = Cardinal.one
    print("Cardinal.one = Cardinal(\(c.rawValue))")
    assert(c.rawValue == 1, "Expected 1")
}

// MARK: - Test: Ordinal(.one) — NO AMBIGUITY even with both in scope
// Result: CONFIRMED — compiles without try, resolves to Ordinal(Cardinal.one) = Ordinal(1)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Key insight: Swift prefers direct members over protocol extension members.
// Cardinal.one is a direct member; Vector.one is a protocol extension member.
// The compiler unambiguously selects Cardinal.one.
func testOrdinalDotOneNoAmbiguity() {
    let ordinal = Ordinal(.one)
    print("Ordinal(.one) = Ordinal(\(ordinal.rawValue))")
    assert(ordinal.rawValue == 1, "Expected 1")
}

// MARK: - Test: Explicit disambiguation still works at algebra layer
func testOrdinalExplicit() {
    let ordinal = Ordinal(Cardinal.one)
    print("Ordinal(Cardinal.one) = Ordinal(\(ordinal.rawValue))")
    assert(ordinal.rawValue == 1, "Expected 1")
}

testVectorOne()
testCardinalOne()
testOrdinalDotOneNoAmbiguity()
testOrdinalExplicit()
print("variant-algebra: All tests passed")
