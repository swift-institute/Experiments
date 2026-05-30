// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Builder_Primitives
import Set_Algebra_Primitives
import Set_Ordered_Primitives
import Testing

// Cross-variant composition coverage for the Set.Buildable.Protocol decoupling.
//
// After the deletion, a growable set inherits the orthogonal algebra purely by
// composing set-primitives' `Set.Protocol` with builder-primitives' `Buildable`
// (constructive) / `Iterable` (predicates) — no bundled protocol. These tests
// prove the REAL variants (`Set.Ordered`, `.Small`, `.Fixed`, `.Static`) compose,
// including cross-variant operands, which the ⊥ invariant forbids testing inside
// either source package.
//
// NB: the inline/bounded variants (`.Small`/`.Static`/`.Fixed`) are `~Copyable`,
// so the `#expect` macro (which captures its operands by value) cannot take them
// directly — each Bool is bound to a `let` first, then asserted.

@Suite("Set Algebra Composition")
struct SetAlgebraCompositionTests {
    @Suite struct GrowableConstructive {}
    @Suite struct CrossVariantConstructive {}
    @Suite struct CrossVariantPredicates {}
    @Suite struct PowersetLattice {}
    @Suite struct DSL {}
}

// MARK: - Growable constructive (Set.Protocol & Buildable & Iterable → Self)

extension SetAlgebraCompositionTests.GrowableConstructive {

    @Test
    func `Set.Ordered inherits union / intersection / subtracting / symmetricDifference`() {
        let a = Set<Int>.Ordered { 1; 2; 3; 4 }
        let b = Set<Int>.Ordered { 3; 4; 5; 6 }

        let u = a.union(b)
        #expect(u.contains(1) && u.contains(5) && u.contains(3))

        let i = a.intersection(b)
        #expect(i.contains(3) && i.contains(4) && !i.contains(1) && !i.contains(5))

        let d = a.subtracting(b)
        #expect(d.contains(1) && d.contains(2) && !d.contains(3) && !d.contains(4))

        let s = a.symmetricDifference(b)
        #expect(s.contains(1) && s.contains(6) && !s.contains(3))
    }

    @Test
    func `Set.Ordered.Small inherits the same constructive algebra`() {
        let a = Set<Int>.Ordered.Small<8> { 1; 2; 3 }
        let b = Set<Int>.Ordered.Small<8> { 2; 3; 4 }

        let unionHas4 = a.union(b).contains(4)
        let interHas2 = a.intersection(b).contains(2)
        let interLacks1 = !a.intersection(b).contains(1)
        let subHas1 = a.subtracting(b).contains(1)
        let subLacks2 = !a.subtracting(b).contains(2)
        #expect(unionHas4)
        #expect(interHas2 && interLacks1)
        #expect(subHas1 && subLacks2)
    }
}

// MARK: - Cross-variant constructive (Self = receiver; Other is a different variant)

extension SetAlgebraCompositionTests.CrossVariantConstructive {

    @Test
    func `Ordered.union(Small) returns Ordered and unions correctly`() {
        let ordered = Set<Int>.Ordered { 1; 2 }
        let small = Set<Int>.Ordered.Small<8> { 2; 3 }
        let result: Set<Int>.Ordered = ordered.union(small)   // Self = Set.Ordered (Copyable)
        #expect(result.contains(1) && result.contains(2) && result.contains(3))
    }

    @Test
    func `Ordered.intersection(Static) probes a bounded operand`() throws {
        let ordered = Set<Int>.Ordered { 1; 2; 3 }
        let bounded = try Set<Int>.Ordered.Static<8> { 2; 3; 9 }
        let result = ordered.intersection(bounded)            // bounded (~Copyable) as borrowed Other
        #expect(result.contains(2) && result.contains(3) && !result.contains(1) && !result.contains(9))
    }
}

// MARK: - Cross-variant predicates (Set.Protocol & Iterable → Bool; bounded variants are predicates-only)

extension SetAlgebraCompositionTests.CrossVariantPredicates {

    @Test
    func `subset / superset across Ordered and Static`() throws {
        let small = Set<Int>.Ordered { 1; 2 }
        let big = try Set<Int>.Ordered.Static<8> { 1; 2; 3; 4 }
        let smallSubsetBig = small.isSubset(of: big)
        let bigNotSubsetSmall = !big.isSubset(of: small)
        let strict = small.isStrictSubset(of: big)
        #expect(smallSubsetBig)
        #expect(bigNotSubsetSmall)
        #expect(strict)
    }

    @Test
    func `disjoint / equal across Ordered and Small`() {
        let a = Set<Int>.Ordered { 1; 2; 3 }
        let b = Set<Int>.Ordered.Small<8> { 4; 5; 6 }
        let c = Set<Int>.Ordered.Small<8> { 1; 2; 3 }
        let disjointAB = a.isDisjoint(with: b)
        let notDisjointAC = !a.isDisjoint(with: c)
        let equalAC = a.isEqual(to: c)
        let notEqualAB = !a.isEqual(to: b)
        #expect(disjointAB)
        #expect(notDisjointAC)
        #expect(equalAC)
        #expect(notEqualAB)
    }

    @Test
    func `Fixed (bounded) inherits predicates`() throws {
        let fixed = try Set<Int>.Ordered.Fixed(capacity: 8) { 1; 2; 3 }
        let other = Set<Int>.Ordered { 1; 2; 3; 4 }
        let fixedSubset = fixed.isSubset(of: other)
        let fixedNotDisjoint = !fixed.isDisjoint(with: other)
        #expect(fixedSubset)
        #expect(fixedNotDisjoint)
    }
}

// MARK: - Powerset lattice (the formal grounding, on the growable variant)

extension SetAlgebraCompositionTests.PowersetLattice {

    @Test
    func `Set.Ordered powerset yields a lattice whose join is union, meet is intersection`() {
        let universe = Set<Int>.Ordered { 1; 2; 3; 4 }
        let lattice = universe.powerset()
        let a = Set<Int>.Ordered { 1; 2 }
        let b = Set<Int>.Ordered { 2; 3 }
        let join = lattice.join(a, b)
        let meet = lattice.meet(a, b)
        #expect(join.contains(1) && join.contains(2) && join.contains(3))
        #expect(meet.contains(2) && !meet.contains(1) && !meet.contains(3))
        #expect(lattice.bottom.isEmpty)
        #expect(lattice.top.contains(4))
    }
}

// MARK: - DSL across all four variants (builder-primitives' @Builder)

extension SetAlgebraCompositionTests.DSL {

    @Test
    func `growable variants build via the free @Builder DSL`() {
        let ordered = Set<Int>.Ordered { 1; 2; 2; 3 }   // dedup on insert
        let small = Set<Int>.Ordered.Small<8> { 4; 5 }
        let smallHas5 = small.contains(5)
        #expect(ordered.contains(3) && !ordered.isEmpty)
        #expect(smallHas5)
    }

    @Test
    func `bounded variants build via the throwing @Builder DSL; overflow throws`() throws {
        let staticSet = try Set<Int>.Ordered.Static<8> { 1; 2; 3 }
        let fixedSet = try Set<Int>.Ordered.Fixed(capacity: 8) { 1; 2; 3 }
        let staticHas2 = staticSet.contains(2)
        let fixedHas2 = fixedSet.contains(2)
        #expect(staticHas2)
        #expect(fixedHas2)

        #expect(throws: (any Error).self) {
            _ = try Set<Int>.Ordered.Static<2> { 1; 2; 3 }   // capacity 2, 3 elements → overflow
        }
    }
}
