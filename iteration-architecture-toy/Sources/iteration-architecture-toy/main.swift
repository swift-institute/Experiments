// MARK: - Iteration Architecture Expressibility Envelope — toy probe
// Purpose: empirically map what the institute's three-route iteration architecture
//          (Iterable / Sequenceable / Iterator.Borrow) + the family-protocol-with-Backing
//          shape can express in current Swift, top-to-bottom, with no package deps.
// Hypothesis (to test): a family protocol that refines Collection.`Protocol`, conditionally
//          conforms Iterable/Sequenceable, and carries makeIterator delegation once via a
//          `Backing` associated type, collapses per-variant iteration boilerplate.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101)
// Platform: macOS 26 (arm64)
//
// Result: PARTIAL — the conformance "lift" is impossible, but the family-protocol-with-Backing
//         shape CAN carry both makeIterator AND forEach delegation once, given the right
//         lifetime design. Positive end-to-end shape found + runs (below).
// Status: CONFIRMED/REFUTED per shape — verified debug + release, clean build, WARNING-CLEAN
//         under the FULL ecosystem settings (strictMemorySafety + Lifetimes + SuppressedAssociatedTypes
//         + ExistentialAny/InternalImportsByDefault/MemberImportVisibility/... — see Package.swift).
//         v1.2.0 adds three GATING verdicts: (a) piecewise D1 CONFIRMED; (b) non-contiguous D1
//         REFUTED (plain makeIterator + forEach survive); (c) cross-module D1/C/route-2 CONFIRMED
//         (debug+release across a lib→exe module boundary).
// Date: 2026-05-28
//
// ============================ EXPRESSIBILITY ENVELOPE =============================
// Verdicts (each = first clean signal per [EXP-011a]; exact diagnostics in the per-file
// source headers — Family.swift (A/B/C), Phase2Revisit.swift (D1/D2/D3), Phase2RevisitRun.swift
// (boundary), Phase5Piecewise.swift (a), Phase6NonContiguous.swift (b), Phase7CrossModule.swift (c)).
// "family default" = a body written ONCE on the family protocol all conformers inherit.
//
//  # | Shape                                                            | Verdict
// ---+------------------------------------------------------------------+-----------------
//  A | LIFT: extension Family.`Protocol`: Iterable where Backing:…       | REFUTED (compile)
//    |   "extension of protocol cannot have an inheritance clause"       |
//  B | makeIterator family default via backing.makeIterator() where the | REFUTED (compile)
//    |   backing makeIterator is @_lifetime(BORROW self)                 |
//    |   "lifetime-dependent value escapes its scope"                   |
// D1 | makeIterator family default via backing.makeIterator() where the | CONFIRMED (run)
//    |   backing is a ~Escapable VIEW with @_lifetime(COPY self)         |  ← the rescue
//  b | makeIterator family default via DIRECT self.span projection      | CONFIRMED (run)
//    |   + @_lifetime(copy span) init  (= the green production bridge)   |
//  C | forEach family default via backing.forEach() delegation          | CONFIRMED (run)
//    |   (route 3, ~Copyable elements — the crux)                        |
//  2 | Sequenceable consuming makeIterator family default (generic      | CONFIRMED in toy
//    |   owning-drain over consumed Self)                                | (real generic path
//    |                                                                  | REFUTED-runtime per
//    |                                                                  | bridge OQ-2; not repro)
//  a | closure-callback withBacking<R>(_ body:(borrowing Backing)->R)   | CONFIRMED (run)
//  c | witness-struct delegation (borrowing-~Copyable closures)         | CONFIRMED (run)
// D2 | makeIterator delegation rescued via _overrideLifetime            | REFUTED (compile)
//    |   (the computed view temporary escapes / cannot be consumed)      |
// D3 | adding `where Element: ~Copyable/~Escapable` to the extension     | REFUTED (compile)
//    |   "cannot suppress '~Copyable' on generic parameter … outer scope"|
//    | boundary: Escapable OWNED container conforming copy-self directly | REFUTED (compile)
//    |   (its ~Escapable iterator escapes the copy-self contract)        |
// ---+------------------------------------------------------------------+-----------------
// GATING VERDICTS (v1.2.0 — piecewise / non-contiguous / cross-module; gate the D1-family-lean
//   vs per-variant-shape-b architecture decision across the ~18 data-structure packages):
//  a | PIECEWISE: D1 over a TWO-SEGMENT (ring/deque) view holding two | CONFIRMED (run,
//    |   spans, NO single span. Iterator/view declare @_lifetime(copy   | debug+release)
//    |   a, copy b) for BOTH segments. → [50,60,10,20,30] in order.    |
//    |   (single-arg @_lifetime(copy a) on a 2-span init = the only    |
//    |   delta; "lifetime-dependent variable 'self' escapes its scope") |
//  b | NON-CONTIGUOUS: D1 over a tree(boxed nodes)/hash(buckets) view, | D1 REFUTED (compile);
//    |   NO span. The copy-self view's makeIterator is rejected:        | PLAIN makeIterator
//    |   "invalid lifetime dependence on an Escapable result" (a node-  | + route-3 forEach
//    |   /bucket iterator is Escapable, so @_lifetime is invalid on it).| (C) SURVIVE.
//    |   → trees/hashes/graphs need a SECOND shape, not the D1 family.  |
//  c | CROSS-MODULE: D1, forEach (C), route-2 across a lib→exe module  | CONFIRMED (run,
//    |   boundary. Downstream conformers inherit upstream lib defaults. | debug+release,
//    |   Only deltas: consumer must `import` the lib (MemberImport-     | cross-module)
//    |   Visibility) + leaf conformers stay internal. Mechanics intact. |
//
// THE GOVERNING PRINCIPLE: a lifetime-dependent return value (an iterator) composes through
// `@_lifetime(COPY …)`, never through `@_lifetime(BORROW <local>)`. `copy` flattens the source's
// own dependency into the result; `borrow` ties it to the local temporary, which escapes.
// COROLLARY (v1.2.0): the COPY-self flatten generalises from one span to N segments — list
// EVERY lifetime-dependent field (`@_lifetime(copy a, copy b)`); but it requires a ~Escapable
// (lifetime-dependent) iterator, so it is INAPPLICABLE where there is no span to borrow
// (Escapable node/bucket iterators reject @_lifetime). Piecewise stays IN the D1 envelope;
// non-contiguous falls OUT of it (plain makeIterator / forEach instead).
//
// THE POSITIVE ARCHITECTURE (compiles + runs end-to-end):
//  1. The conformance LIFT is impossible (A): each variant declares `: Iterable`/`: Sequenceable`
//     itself (one line; @_implements to disambiguate the dual Iterator). Conformance is per-variant;
//     the BODY is inherited.
//  2. makeIterator CAN be a single family default via Backing delegation (D1) — IF the Backing is a
//     ~Escapable VIEW whose makeIterator is @_lifetime(copy self). The variant EXPOSES such a view
//     (e.g. a span view) and inherits the delegated makeIterator. This achieves the handoff's
//     "Backing carries makeIterator delegation once." (The substrate-direct form (b) — borrow-self
//     over self.span — is the alternative when no view indirection is wanted.)
//  3. forEach (route 3, ~Copyable) delegates through a single Backing family default (C). withBacking
//     (a) and witness-struct (c) are equivalent internal-iteration shapes.
//  4. Lifetime-shape split: an Escapable OWNED container takes @_lifetime(borrow self) makeIterator
//     (direct, Shape b); a ~Escapable VIEW takes @_lifetime(copy self) (delegable, D1). They do not
//     unify into one protocol — but the family delegates through the copy-self view regardless.
//  5. The CONSUMING route (2) needs OWNED storage to consume; it cannot share the borrowing routes'
//     ~Escapable Backing view. Route 2 stays its own conformance.
//
// SCOPE ([EXP-017]): the original single-module caveat is now LIFTED for D1/C/route-2 — gap (c)
// validates them across a real lib→executable module boundary in debug AND release (warning-clean).
// Refutations (A, B, D2, D3, boundary, non-contiguous-D1) are module-independent (compile errors).
// Piecewise (a) and non-contiguous-surviving-routes (b) are validated single-module debug+release;
// gap (c) additionally proves the contiguous D1/C/route-2 family-default mechanics cross a module
// boundary. Remaining caveat: the toy is faithful in shape + build settings (full ecosystem flags),
// but minimal — an expressibility probe, not a performance/ABI probe.
// =================================================================================

import iteration_architecture_toy_lib  // gap (c): cross-module family-default consumption

print("iteration-architecture-toy — see source headers + Findings block for per-shape verdicts")

// MARK: Route 1 (Iterable, multipass copy) — RUNTIME
do {
    let set = ToySet([10, 20, 30])
    var iterator = set.makeIterator()
    var collected: [Int] = []
    while let element = iterator.next() { collected.append(element) }
    print("route 1 (Iterable makeIterator over span): \(collected)")
    precondition(collected == [10, 20, 30], "route 1 mismatch")
}

// MARK: Route 3 (Iterator.Borrow forEach, ~Copyable elements) — RUNTIME (the crux)
do {
    let owned = ToyOwned([100, 200, 300])
    var sum = 0
    owned.forEach { resource in sum &+= resource.id }
    print("route 3 (forEach borrowing ~Copyable): sum=\(sum)")
    precondition(sum == 600, "route 3 mismatch")
}

// MARK: Route 2 (Sequenceable, consuming drain via GENERIC owning iterator) — RUNTIME
do {
    let drainable = ToyDrainable([1, 2, 3, 4])
    var iterator = drainable.makeIterator()
    var total = 0
    while let element = iterator.next() { total &+= element }
    print("route 2 (Sequenceable drain, generic owning iterator): total=\(total)")
    precondition(total == 10, "route 2 mismatch")
}

// MARK: Phase 4 alt (a) — closure-callback withBacking — RUNTIME
do {
    let owned = ToyOwned([5, 7, 9])
    let count = owned.withBacking { backing -> Int in
        var c = 0
        backing.forEach { _ in c &+= 1 }
        return c
    }
    print("alt (a) withBacking closure-callback: count=\(count)")
    precondition(count == 3, "alt (a) mismatch")
}

// MARK: Phase 4 alt (c) — witness-struct delegation — RUNTIME
do {
    let witness = BorrowForEachWitness<ToyOwned, Resource> { source, body in
        source.forEach(body)
    }
    let owned = ToyOwned([2, 4, 6])
    var sum = 0
    witness.forEach(owned) { resource in sum &+= resource.id }
    print("alt (c) witness-struct delegation: sum=\(sum)")
    precondition(sum == 12, "alt (c) mismatch")
}

// MARK: D1 — copy-lifetime makeIterator DELEGATION via Backing (the rescue) — RUNTIME
do {
    let impl = FamDImpl([11, 22, 33])
    var iterator = impl.makeIteratorD1()
    var collected: [Int] = []
    while let element = iterator.next() { collected.append(element) }
    print("D1 (copy-lifetime makeIterator delegation via Backing): \(collected)")
    precondition(collected == [11, 22, 33], "D1 mismatch")
}

// MARK: Gap (a) — PIECEWISE ring: D1 over a TWO-SEGMENT view — RUNTIME
do {
    // capacity-6 backing; logical ring = storage[head..<6] ++ storage[0..<tail].
    // head=4 tail=3 → logical order: [50, 60] ++ [10, 20, 30] = [50, 60, 10, 20, 30].
    let ring = ToyRing(storage: [10, 20, 30, 0, 50, 60], head: 4, tail: 3)
    var iterator = ring.makeIteratorD1()
    var collected: [Int] = []
    while let element = iterator.next() { collected.append(element) }
    print("gap (a) piecewise ring (D1 over two segments): \(collected)")
    precondition(collected == [50, 60, 10, 20, 30], "gap (a) piecewise mismatch")
}

// MARK: Gap (b) — NON-CONTIGUOUS (tree + hash): D1 REFUTED; PLAIN makeIterator + forEach survive — RUNTIME
do {
    // Binary tree:        4
    //                   /   \
    //                  2     6     in-order: [1, 2, 3, 4, 5, 6, 7]
    //                 / \   / \
    //                1   3 5   7
    let root = TreeNode(4,
        left: TreeNode(2, left: TreeNode(1), right: TreeNode(3)),
        right: TreeNode(6, left: TreeNode(5), right: TreeNode(7)))
    let tree = ToyTree(root: root)

    // surviving route 1: plain (Escapable) external makeIterator (NOT D1 copy-self)
    var treeIter = tree.makeIterator()
    var inOrder: [Int] = []
    while let v = treeIter.next() { inOrder.append(v) }
    print("gap (b) non-contiguous tree (PLAIN makeIterator, D1 refuted): \(inOrder)")
    precondition(inOrder == [1, 2, 3, 4, 5, 6, 7], "gap (b) tree makeIterator mismatch")

    // surviving route 2: route-3 forEach (shape C) — internal iteration, no span
    var treeSum = 0
    tree.forEach { treeSum &+= $0 }
    print("gap (b) non-contiguous tree (forEach, route 3): sum=\(treeSum)")
    precondition(treeSum == 28, "gap (b) tree forEach mismatch")

    // hash (array-of-buckets, separate chaining): walk bucket chains in order
    let hash = ToyHash(buckets: [[10, 11], [], [22], [30, 31, 32]])
    var hashIter = hash.makeIterator()
    var hashCollected: [Int] = []
    while let v = hashIter.next() { hashCollected.append(v) }
    print("gap (b) non-contiguous hash (PLAIN makeIterator): \(hashCollected)")
    precondition(hashCollected == [10, 11, 22, 30, 31, 32], "gap (b) hash makeIterator mismatch")
}

// MARK: Gap (c) — CROSS-MODULE: D1 / forEach (C) / route-2 across a module boundary — RUNTIME
// Downstream conformers (executable module) ride family defaults defined in the LIB module.
do {
    // D1 across the boundary: makeIteratorD1 body lives in the lib; XMFamDImpl inherits it.
    let impl = XMFamDImpl([14, 25, 36])
    var iterator = impl.makeIteratorD1()
    var collected: [Int] = []
    while let element = iterator.next() { collected.append(element) }
    print("gap (c) cross-module D1 (copy-self makeIterator via lib default): \(collected)")
    precondition(collected == [14, 25, 36], "gap (c) cross-module D1 mismatch")

    // route-3 forEach (C) across the boundary: forEach body lives in the lib.
    let owned = XMOwned([100, 200, 300])
    var sum = 0
    owned.forEach { resource in sum &+= resource.id }
    print("gap (c) cross-module forEach (route 3, C, via lib default): sum=\(sum)")
    precondition(sum == 600, "gap (c) cross-module forEach mismatch")

    // route-2 across the boundary: consuming drain makeIterator body lives in the lib.
    let drainable = XMDrainable([1, 2, 3, 4])
    var drainIter = drainable.makeIterator()
    var total = 0
    while let element = drainIter.next() { total &+= element }
    print("gap (c) cross-module route-2 (consuming drain via lib default): total=\(total)")
    precondition(total == 10, "gap (c) cross-module route-2 mismatch")
}

