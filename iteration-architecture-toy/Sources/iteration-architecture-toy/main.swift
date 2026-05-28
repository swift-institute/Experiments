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
// Date: 2026-05-28
//
// ============================ EXPRESSIBILITY ENVELOPE =============================
// Verdicts (each = first clean signal per [EXP-011a]; exact diagnostics in the per-file
// source headers — Family.swift (A/B/C), Phase2Revisit.swift (D1/D2/D3), Phase2RevisitRun.swift
// (boundary)). "family default" = a body written ONCE on the family protocol all conformers inherit.
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
//
// THE GOVERNING PRINCIPLE: a lifetime-dependent return value (an iterator) composes through
// `@_lifetime(COPY …)`, never through `@_lifetime(BORROW <local>)`. `copy` flattens the source's
// own dependency into the result; `borrow` ties it to the local temporary, which escapes.
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
// SCOPE CAVEAT ([EXP-017]): single-module. Refutations (A, B, D2, D3) are module-independent
// (compile errors). The positive D1/C delegations mirror the production bridge's cross-module
// shape; cross-module re-validation deferred to the real-package fan-out.
// =================================================================================

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

