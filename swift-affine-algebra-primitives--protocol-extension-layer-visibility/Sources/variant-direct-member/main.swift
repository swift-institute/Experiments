// MARK: - Variant 3: Direct Member .one (current production state — CONTROL)
// Purpose: Confirm the hazard exists when .one is a DIRECT member on Vector
//          (not via protocol extension). This is the control variant.
// Hypothesis: With .one as a direct member on Vector, Ordinal(.one) is ambiguous
//             because both Cardinal.one and Vector.one are direct members —
//             the compiler cannot decide between them.
//
// Toolchain: swift-6.2-DEVELOPMENT-SNAPSHOT (Xcode 26 beta)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — "ambiguous use of 'one'" when both are direct members
// Date: 2026-02-11

import BaseTypes
import DirectOneModule

// MARK: - Test: Ordinal(.one) — AMBIGUOUS (hazard present)
// error: ambiguous use of 'one'
//   note: found this candidate in module 'BaseTypes' (Cardinal.one)
//   note: found this candidate in module 'DirectOneModule' (Vector.one)
//
// Uncomment to reproduce:
// func testHazardPresent() {
//     let ordinal = Ordinal(.one)  // ❌ ambiguous use of 'one'
// }

// MARK: - Test: try Ordinal(.one) — ALSO AMBIGUOUS
// Even with `try`, the ambiguity remains because the compiler cannot
// determine which `.one` to use before considering throwability.
//
// Uncomment to reproduce:
// func testHazardWithTry() {
//     let ordinal = try! Ordinal(.one)  // ❌ ambiguous use of 'one'
// }

// MARK: - Test: Explicit disambiguation works
func testExplicitDisambiguation() {
    let ordinal = Ordinal(Cardinal.one)
    print("Ordinal(Cardinal.one) = Ordinal(\(ordinal.rawValue))")
    assert(ordinal.rawValue == 1, "Expected 1")
}

// MARK: - Test: Vector.one as direct member works
func testVectorOneDirectMember() {
    let v = Vector.one
    print("Vector.one (direct) = Vector(\(v.rawValue))")
    assert(v.rawValue == 1, "Expected 1")
}

testExplicitDisambiguation()
testVectorOneDirectMember()
print("variant-direct-member: All tests passed")
