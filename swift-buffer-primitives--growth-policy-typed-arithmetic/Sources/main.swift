// MARK: - Growth Policy Typed Arithmetic
// Purpose: Verify that Buffer.Growth.Policy.factor and .pageAligned
//          can be rewritten using typed arithmetic (no raw UInt/Int)
//
// Hypothesis H1: Ratio<Storage, Storage> works for factor scaling
//   - Count * Ratio<Storage, Storage> -> Count (same-domain multiplication)
//   - Ratio<Storage, Storage> conforms to ExpressibleByIntegerLiteral (From == To)
//   - Count.max(_, _) handles the minimum-of-one requirement
//
// Hypothesis H2: Memory.Alignment.alignUp can accept Cardinal
//   - alignUp is generic over FixedWidthInteger
//   - Cardinal does NOT conform to FixedWidthInteger
//   - Therefore alignUp(Cardinal) should NOT compile
//   - Need to determine the minimal typed boundary conversion
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Status: SUPERSEDED 2026-04-30 — Storage namespace migrated to Storage<Element>; Ratio<Storage, Storage> dimensional pattern no longer expressible without changing Index/Count tag
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Platform: macOS 26.0 (arm64)
//
// Result: H1 CONFIRMED — Ratio<Storage, Storage> works for factor scaling
//         H2 CONFIRMED — alignUp(Cardinal) does NOT compile
//         pageAligned requires .rawValue.rawValue boundary (or new alignUp(Cardinal) overload)
// Date: 2026-02-04

import Buffer_Primitives_Core

// MARK: - Variant 1: factor via Ratio<Storage, Storage>
// Hypothesis: Count * Ratio<Storage, Storage> compiles and produces Count
// Result: CONFIRMED — Output: 3 (1 * 3)

func testFactorWithRatio() {
    typealias Count = Index<Storage>.Count
    typealias Scale = Affine.Discrete.Ratio<Storage, Storage>

    let current: Count = .one
    let scale: Scale = Scale(3)

    // Count * Ratio<Storage, Storage> -> Count
    let grown: Count = current * scale
    print("V1a - factor via explicit Ratio: \(grown)")

    // Same but using integer literal (From == To enables ExpressibleByIntegerLiteral)
    let grownLiteral: Count = current * 3
    print("V1b - factor via literal: \(grownLiteral)")
}

// MARK: - Variant 2: factor with max for minimum-of-one
// Hypothesis: Count.max handles the zero-capacity edge case
// Result: CONFIRMED — max(0 * 3, 1) = 1; max(4 * 3, 1) = 12

func testFactorWithMax() {
    typealias Count = Index<Storage>.Count

    let zero: Count = .zero
    let scale: Affine.Discrete.Ratio<Storage, Storage> = 3

    // Scale then clamp to minimum of one
    let grown: Count = Count.max(zero * scale, .one)
    print("V2 - factor with max: \(grown)")

    let four: Count = Count(Cardinal(4))
    let grownFour: Count = Count.max(four * scale, .one)
    print("V2b - factor(4 * 3): \(grownFour)")
}

// MARK: - Variant 3: pageAligned — alignUp does NOT accept Cardinal
// Hypothesis: alignUp(Cardinal) does not compile (Cardinal is not FixedWidthInteger)
// Result: CONFIRMED — error: requires that 'Cardinal' conform to 'FixedWidthInteger'
//
// func testAlignUpCardinal() {
//     let alignment = try! Memory.Alignment(4096)
//     let value: Cardinal = Cardinal(100)
//     let aligned = alignment.alignUp(value)  // ERROR: requires FixedWidthInteger
// }

// MARK: - Variant 4: pageAligned — alignUp with rawValue boundary
// Hypothesis: alignUp(count.rawValue.rawValue) is the minimal typed boundary
// Result: CONFIRMED — alignUp(100 UInt) = 4096

func testAlignUpBoundary() {
    typealias Count = Index<Storage>.Count

    let alignment = try! Memory.Alignment(4096)
    let current: Count = Count(Cardinal(100))

    // Option A: rawValue.rawValue to reach UInt (two layers)
    let alignedA = alignment.alignUp(current.rawValue.rawValue)
    let resultA: Count = Count(Cardinal(alignedA))
    print("V4a - alignUp via rawValue.rawValue: \(resultA)")

    // Option B: If Cardinal had alignUp, we'd write:
    //   let aligned = alignment.alignUp(current.rawValue)
    //   let result = Count(aligned)
    // This would need Cardinal: FixedWidthInteger OR
    // Memory.Alignment.alignUp(_: Cardinal) -> Cardinal
}

// MARK: - Variant 5: pageAligned with max for minimum-of-one
// Hypothesis: max + alignUp composes cleanly
// Result: CONFIRMED — pageAligned(0) = 4096, pageAligned(100) = 4096

func testPageAlignedWithMax() {
    typealias Count = Index<Storage>.Count

    let alignment = try! Memory.Alignment(4096)
    let zero: Count = .zero

    // Ensure at least one, then align
    let atLeastOne: Count = Count.max(zero, .one)
    let aligned = alignment.alignUp(atLeastOne.rawValue.rawValue)
    let result: Count = Count(Cardinal(aligned))
    print("V5 - pageAligned(zero): \(result)")

    let hundred: Count = Count(Cardinal(100))
    let atLeastOne2: Count = Count.max(hundred, .one)
    let aligned2 = alignment.alignUp(atLeastOne2.rawValue.rawValue)
    let result2: Count = Count(Cardinal(aligned2))
    print("V5b - pageAligned(100): \(result2)")
}

// MARK: - Execute

testFactorWithRatio()
testFactorWithMax()
testAlignUpBoundary()
testPageAlignedWithMax()

// MARK: - Results Summary
// V1: CONFIRMED — Count * Ratio<Storage, Storage> -> Count works
// V2: CONFIRMED — Count.max(scaled, .one) handles zero edge case
// V3: CONFIRMED — alignUp(Cardinal) does NOT compile (negative test)
// V4: CONFIRMED — alignUp(count.rawValue.rawValue) works as boundary conversion
// V5: CONFIRMED — max + alignUp composes correctly
//
// Conclusions:
// - factor: fully typed via Ratio<Storage, Storage>. No rawValue needed.
//   Perfect syntax: Count.max(current * scale, .one)
// - pageAligned: requires .rawValue.rawValue to reach UInt for alignUp.
//   Would need Memory.Alignment.alignUp(Cardinal) -> Cardinal to eliminate.
//   This is a system boundary — alignUp operates on bit patterns (FixedWidthInteger).
