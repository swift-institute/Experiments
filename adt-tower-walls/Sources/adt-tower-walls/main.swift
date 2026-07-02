// MARK: - adt-tower-walls — runtime probes (cross-package half)
//
// Purpose:   Re-probe, on the CURRENT toolchain, the runtime walls the ADT-tower
//            re-derivation depends on:
//            A. Protocol-vended borrowing access to ~Copyable elements — generic
//               code constrained to a Store.Protocol-shaped seam borrowing and
//               mutating a ~Copyable element ACROSS A PACKAGE BOUNDARY through a
//               `{ get set }` requirement witnessed by `_read`/`_modify`.
//            B. Wall 2 (swiftlang/swift#86652) WITH the [MEM-SAFE-027]
//               _deinitWorkaround: cross-package drop of a @_rawLayout store must
//               run the deinit oracle (expect 2 deinits).
//            C. Wall 2 WITHOUT the workaround (the naked #86652 shape): if the bug
//               persists, cross-package drop skips the deinit (expect 0 deinits
//               under the bug; 2 if fixed).
//
// Hypothesis: A works (verified 2026-06-18 on 6.3.2 via the seam experiment +
//            in-tree Store.Protocol docs); B works (the workaround forces
//            non-trivial destructibility); C still leaks on 6.3.3 (#86652 open).
//
// Toolchain: Apple Swift 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101), macOS 26 (arm64), Xcode 26.6
// Platform:  macOS 26 (arm64)
//
// Result:    CONFIRMED (A, B) / STILL PRESENT with a debug/release asymmetry (C) —
//   A. PASSES debug+release: "A: peek=10 sum=60 afterBump=61" — borrowing member read
//      AND in-place `_modify` mutation of a ~Copyable element through the `{ get set }`
//      protocol requirement, cross-package, fully generic. (Twin probe p11b: whole-value
//      +1 extraction through the same requirement is REJECTED at SIL — "noncopyable
//      's.subscript' cannot be consumed…" — borrow/mutate yes, move-out no. Sound.)
//   B. PASSES debug+release: 2/2 deinits — the [MEM-SAFE-027] _deinitWorkaround keeps
//      the deinit oracle firing cross-package.
//   C. Wall 2 (swiftlang/swift#86652) STILL PRESENT on 6.3.3 — ASYMMETRICALLY:
//      debug = 0 deinits (value witness misclassified trivial; elements LEAK);
//      release = 2 deinits (specialization bypasses the witness path).
//      The workaround remains REQUIRED for cross-package @_rawLayout stores.
//      (Probes/p12: stdlib InlineArray<2, NC> with a same-file element deinits 2/2
//      in BOTH debug and -O — the leak needs the naked custom-store shape.)
// Revalidated: Swift 6.3.3 (2026-07-02) — A/B PASSES; C STILL PRESENT (debug)
// Date:      2026-07-02

import WallKit

// MARK: A — generic algorithms over the seam, cross-package, ~Copyable element

func peekV<S: SeamP & ~Copyable>(_ s: borrowing S) -> Int where S.Element == NC {
    s[0].v // borrowing member read THROUGH the protocol requirement
}

func bumpV<S: SeamP & ~Copyable>(_ s: inout S, at slot: Int) where S.Element == NC {
    s[slot].v += 1 // in-place mutation through the `_modify` witness
}

func sumV<S: SeamP & ~Copyable>(_ s: borrowing S, count: Int) -> Int where S.Element == NC {
    var total = 0
    for i in 0..<count { total += s[i].v }
    return total
}

do {
    var store = PtrStore<NC>(capacity: 4)
    store.initialize(at: 0, to: NC(10))
    store.initialize(at: 1, to: NC(20))
    store.initialize(at: 2, to: NC(30))
    let peek = peekV(store)
    let sum = sumV(store, count: 3)
    bumpV(&store, at: 1)
    let after = sumV(store, count: 3)
    print("A: peek=\(peek) sum=\(sum) afterBump=\(after)") // expect 10, 60, 61
}

// MARK: B — Wall 2 WITH the workaround

Probe.deinitCount = 0
do {
    var b = Inline4W<NC>()
    b.append(NC(1))
    b.append(NC(2))
}
print("B: deinits(with workaround)=\(Probe.deinitCount) (expect 2)")

// MARK: C — Wall 2 WITHOUT the workaround (naked #86652 shape)

Probe.deinitCount = 0
do {
    var c = Inline4N<NC>()
    c.append(NC(1))
    c.append(NC(2))
}
print("C: deinits(no workaround)=\(Probe.deinitCount) (2 = fixed, 0 = #86652 persists)")
