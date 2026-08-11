// MARK: - Variant 1: Affine Layer Only (no algebra import)
// Purpose: Verify that Ordinal(.one) resolves unambiguously to Ordinal(Cardinal.one)
//          when Vector does NOT have .one (algebra layer not imported)
// Hypothesis: Without AlgebraExtension, Vector has no .one, so Ordinal(.one) is
//             unambiguous — only Cardinal.one matches
//
// Toolchain: swift-6.2-DEVELOPMENT-SNAPSHOT (Xcode 26 beta)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Ordinal(.one) compiles without try, resolves to Ordinal(1)
// Date: 2026-02-11

import BaseTypes

// MARK: - Test: Ordinal(.one) compiles without try
// Result: CONFIRMED — Build Succeeded, output: Ordinal(.one) = Ordinal(1)
func testOrdinalDotOne() {
    let ordinal = Ordinal(.one)
    print("Ordinal(.one) = Ordinal(\(ordinal.rawValue))")
    assert(ordinal.rawValue == 1, "Expected 1")
}

// MARK: - Test: Vector.one does NOT compile
// Uncomment to verify Vector.one is unavailable at this layer:
// let v = Vector.one  // ❌ 'one' is not a member of 'Vector'

// MARK: - Test: Cardinal.one still works
func testCardinalOne() {
    let c = Cardinal.one
    print("Cardinal.one = Cardinal(\(c.rawValue))")
    assert(c.rawValue == 1, "Expected 1")
}

// MARK: - Test: Vector.zero still works (additive identity is at affine layer)
func testVectorZero() {
    let v = Vector.zero
    print("Vector.zero = Vector(\(v.rawValue))")
    assert(v.rawValue == 0, "Expected 0")
}

testOrdinalDotOne()
testCardinalOne()
testVectorZero()
print("variant-affine-only: All tests passed")
