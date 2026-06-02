// MARK: - Viability of a ~Escapable scoped-slice view
//
// Purpose: Decide whether a ~Escapable scoped-slice VIEW is viable on BOTH Swift 6.3.2
//   and 6.5-dev — a slice that is itself ~Escapable, storing its two ~Escapable bound
//   indices directly (no stored Range) plus a borrow of the base, produced by a
//   borrowing-bounds subscript, offering within-scope indexed sub-access.
//
// Hypothesis (refute-first): a ~Escapable struct CAN store ~Escapable bound indices and
//   offer within-scope indexed sub-access — yielding a viable ~Escapable scoped-slice.
//   This is the residual that collection-slice-escapable-index-toolchain-fallout.md
//   v1.1.0 left untested: its Option-B obstruction (`stored property of 'Escapable'-
//   conforming struct has non-Escapable type`) was the ~Escapable-index-in-*Escapable*-
//   struct case; this tests ~Escapable-index-in-*~Escapable*-struct. It is also the
//   "scoped view" consumer-fallout.md v1.3.0 §Foreclosed names as the honest model, and
//   its steelman #4 ("a borrowed/handle/scoped-cursor index … could offer within-scope
//   indexed random access while ~Escapable").
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108) AND 6.5-dev
//   (org.swift.64202605121a, LLVM 7c86461e21cca7e, Swift 6da4da7153e8252),
//   arm64-apple-macos26.0. The multi-toolchain gate is load-bearing per [MEM-LIFE-004]
//   (@_lifetime semantics have a documented 6.2.x/6.4-dev version skew).
//
// Variants (each its own target; build individually):
//   ScopedSliceKit         — the candidate viable shape (lib)
//   (this target)          — cross-module consumer: within-scope runtime probe (exe; [EXP-017])
//   IndexedSubscriptProbe  — view subscript taking a ~Escapable param (lib)
//   EscapeRejection        — negative controls: escape MUST be rejected (lib; EXPECT-FAIL)
//
// Status: CONFIRMED (viable, BOTH toolchains) — with one shape caveat: the bounds
//   PRODUCER must be a `func`, not a subscript (SubscriptProducerProbe REFUTED on both).
// Result: VIABLE. A ~Escapable struct CAN store two ~Escapable bound indices + a base
//   borrow, be produced by a borrowing-bounds `func` (no stored Range), offer within-scope
//   indexed sub-access (offset-keyed AND ~Escapable-cursor-keyed subscript), and is
//   escape-rejected. Identical on Apple Swift 6.3.2 and 6.5-dev — the [MEM-LIFE-004]
//   @_lifetime version-skew did NOT fire (same `@_lifetime(copy lower, copy upper)` /
//   `@_lifetime(borrow base)` annotations compile on both). The residual that
//   collection-slice-escapable-index-toolchain-fallout.md left untested is a REAL frontier:
//   the consumer-fallout v1.3.0 §Foreclosed "scoped view" / steelman #4 is achievable today.
// Date: 2026-06-02
//
// MARK: - Results Matrix (`[Verified: 2026-06-02]`; clean per-toolchain build dir)
//
//   Target / check                         | 6.3.2 (swiftlang-6.3.2.1.108) | 6.5-dev (org.swift.64202605121a)
//   ---------------------------------------|-------------------------------|---------------------------------
//   ScopedSliceKit (store 2 NE idx+borrow) | ✅ build                       | ✅ build
//   exe (cross-module, debug) + run        | ✅ run, sum=90                 | ✅ run, sum=90
//   exe (cross-module, RELEASE) + run      | ✅ run, sum=90 ([EXP-017])     | ✅ run, sum=90 ([EXP-017])
//   ~Escapable-cursor-keyed element subscript | ✅ (slice[at: lo] = 20)     | ✅ (slice[at: lo] = 20)
//   SubscriptProducerProbe (producer=subscript) | ❌ REFUTED (see below)    | ❌ REFUTED (identical)
//   EscapeRejection control 1 (store in Escapable struct) | ❌ rejected ✓  | ❌ rejected ✓ (identical)
//   EscapeRejection control 2 (return w/o @_lifetime)     | ❌ rejected ✓  | ❌ rejected ✓ (identical)
//
//   OBSTRUCTION (the bounds producer cannot be a subscript — must be a `func`):
//     (A) `subscript(... lower: borrowing Cursor ...)`:
//         error: 'borrowing' may only be used on function or initializer parameters
//     (B) `subscript(... lower: Cursor ...) -> ScopedSlice` (~Escapable return, by value):
//         error: lifetime-dependent value escapes its scope
//         note: error in compiler-generated 'get' / it depends on the lifetime of argument 'lower'
//     The cursor-keyed ELEMENT subscript (returns Int, Escapable) compiles — only the
//     ~Escapable-RETURNING producer subscript is obstructed.
//
//   ESCAPE REJECTION IS REAL (not vacuous):
//     control 1: error: stored property 'slice' of 'Escapable'-conforming struct
//                'EscapableHolder' has non-Escapable type 'ScopedSlice'
//                (note: consider adding '~Escapable' to struct 'EscapableHolder' — i.e.
//                 exactly what ScopedSlice does; the symmetric counterpart of the
//                 toolchain-fallout doc's Option-B obstruction)
//     control 2: error: a function with a ~Escapable result requires '@_lifetime(...)'
//
//   PRIOR ART (the core ~Escapable-field storage was already known; this composite +
//   multi-toolchain gate + escape control + producer-shape is the new contribution):
//     swift-institute/Experiments/pointer-nonescapable-storage  (TuplePair/Triple: N ~Escapable
//       fields under @_lifetime(copy a, copy b[, copy c]) — CONFIRMED)
//     swift-institute/Experiments/escapable-output-borrow-lend  (bespoke ~Escapable Borrowed
//       view under @_lifetime(borrow owner) — CONFIRMED 6.3.2)
//     swift-collection-primitives/Experiments/collection-index-escapable-lifetime
//       (@_lifetime(copy i) for the storable-index contract — CONFIRMED 6.3.2; this extends it)
//     swift-collection-primitives/Experiments/self-slicing-noncopyable,
//       …/protocol-subscript-noncopyable (the ~Copyable self-slice / subscript axis)

import ScopedSliceKit

// Within-scope exercise: build a base over caller-owned memory, take a scoped slice over
// a sub-range via the borrowing-bounds subscript, and read THROUGH it within the borrow.
// The slice is ~Escapable; it cannot outlive `buf` — see the EscapeRejection target.
let data = [10, 20, 30, 40, 50]
let observed: Int = data.withUnsafeBufferPointer { buf in
    let base = Base(buf)
    let lo = Cursor(1, in: base)              // -> element 20
    let hi = Cursor(4, in: base)              // -> one past element 40
    let slice = base.slice(from: lo, upTo: hi)   // ~Escapable scoped-slice view over [1, 4)

    print("within-scope sum   =", slice.sum())            // 20 + 30 + 40 = 90
    print("within-scope count =", slice.count)            // 3
    print("within-scope [0]   =", slice.element(at: 0))   // 20 (offset-keyed)
    print("within-scope [2]   =", slice.element(at: 2))   // 40 (offset-keyed)
    print("within-scope [at lo] =", slice[at: lo])        // 20 (~Escapable-cursor-keyed subscript)
    print("lower.isBefore(upper) =", lo.isBefore(hi))     // true
    return slice.sum()
}

print("observed sum =", observed)
precondition(observed == 90, "scoped-slice within-scope read must sum 90")
print("OK: ~Escapable scoped-slice view is usable within the borrow")
