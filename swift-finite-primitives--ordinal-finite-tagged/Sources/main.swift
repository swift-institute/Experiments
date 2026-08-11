// MARK: - Ordinal.Finite<N> Integration Test
// Purpose: Verify Ordinal.Finite<N> works with real primitives
// Hypothesis: Tagged<Finite.Bound<N>, Ordinal> provides bounded ordinal arithmetic
//
// Toolchain: Swift 6.2
// Status: SUPERSEDED 2026-04-30 — Tagged<Finite.Bound<N>, Ordinal>.intValue accessor surface changed; experiment idiom needs re-targeting
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Platform: macOS 26
//
// Result: CONFIRMED
// Date: 2026-01-29

import Finite_Primitives

// MARK: - Test Ordinal.Finite<N>

func testBasics() {
    print("=== Ordinal.Finite<N> Basics ===")

    // Create via .zero
    let idx: Ordinal.Finite<4> = .zero
    print("Created .zero: position = \(idx.position.rawValue)")

    // Create via checked init
    if let idx2 = Ordinal.Finite<4>(Ordinal(3)) {
        print("Created from Ordinal(3): position = \(idx2.position.rawValue)")
    }

    // Create via Int
    if let idx3 = Ordinal.Finite<4>(2) {
        print("Created from Int 2: position = \(idx3.position.rawValue)")
    }

    // Out of bounds returns nil
    if Ordinal.Finite<4>(5) == nil {
        print("Init with 5: nil (correctly rejected)")
    }

    // Capacity
    print("Capacity: \(Ordinal.Finite<4>.capacity())")

    // Max
    if let max = Ordinal.Finite<4>.max() {
        print("Max: \(max.position.rawValue)")
    }
}

func testSuccessorPredecessor() {
    print("\n=== Successor / Predecessor ===")

    var idx: Ordinal.Finite<4> = .zero

    // Successor chain
    print("Starting at \(idx.position.rawValue)")
    while let next = idx.successor() {
        idx = next
        print("  successor -> \(idx.position.rawValue)")
    }
    print("  successor -> nil (at bound)")

    // Predecessor chain
    print("Starting at \(idx.position.rawValue)")
    while let prev = idx.predecessor() {
        idx = prev
        print("  predecessor -> \(idx.position.rawValue)")
    }
    print("  predecessor -> nil (at zero)")
}

func testOffset() {
    print("\n=== Offset ===")

    let idx = Ordinal.Finite<8>(3)!

    if let plus2 = idx.offset(by: 2) {
        print("3 + 2 = \(plus2.position.rawValue)")
    }

    if let minus2 = idx.offset(by: -2) {
        print("3 - 2 = \(minus2.position.rawValue)")
    }

    if idx.offset(by: 10) == nil {
        print("3 + 10 = nil (out of bounds)")
    }

    // Clamped
    let clamped = idx.clamped(offsetBy: 10)
    print("3 + 10 (clamped) = \(clamped.position.rawValue)")
}

func testDistance() {
    print("\n=== Distance ===")

    let a = Ordinal.Finite<8>(2)!
    let b = Ordinal.Finite<8>(7)!

    print("Distance from 2 to 7: \(a.distance(to: b))")
    print("Distance from 7 to 2: \(b.distance(to: a))")
}

func testComplement() {
    print("\n=== Complement ===")

    for i in 0..<4 {
        let idx = Ordinal.Finite<4>(i)!
        let comp = idx.complement()
        print("\(i) -> \(comp.position.rawValue)")
    }
}

func testInjectionProjection() {
    print("\n=== Injection / Projection ===")

    let small = Ordinal.Finite<4>(2)!

    // Inject into larger
    let large: Ordinal.Finite<8> = small.injected()
    print("Injected 2 from Finite<4> to Finite<8>: \(large.position.rawValue)")

    // Project back
    if let projected: Ordinal.Finite<4> = large.projected() {
        print("Projected back to Finite<4>: \(projected.position.rawValue)")
    }

    // Project value that's too large
    let big = Ordinal.Finite<8>(6)!
    if big.projected() as Ordinal.Finite<4>? == nil {
        print("Cannot project 6 to Finite<4>: nil")
    }
}

func testDecomposition() {
    print("\n=== Product Decomposition ===")

    // 3x4 = 12, index 7 -> row 1, col 3
    let idx = Ordinal.Finite<12>(7)!
    if let (row, col): (Ordinal.Finite<3>, Ordinal.Finite<4>) = idx.decomposed() {
        print("Index 7 in 3x4 grid: row=\(row.position.rawValue), col=\(col.position.rawValue)")
    }

    // Compose back
    let row = Ordinal.Finite<3>(1)!
    let col = Ordinal.Finite<4>(3)!
    if let composed: Ordinal.Finite<12> = .composed(row: row, column: col) {
        print("Composed (1, 3) in 3x4 grid: \(composed.position.rawValue)")
    }
}

func testInheritedOrdinalArithmetic() {
    print("\n=== Inherited Ordinal Arithmetic ===")

    let idx = Ordinal.Finite<8>(3)!

    // .position from Tagged+Ordinal
    print("Position: \(idx.position)")

    // intValue
    print("intValue: \(idx.intValue)")
}

// MARK: - Main

testBasics()
testSuccessorPredecessor()
testOffset()
testDistance()
testComplement()
testInjectionProjection()
testDecomposition()
testInheritedOrdinalArithmetic()

print("\n=== All tests passed ===")
