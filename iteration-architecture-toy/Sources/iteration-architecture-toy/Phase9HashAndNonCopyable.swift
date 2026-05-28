// MARK: - Phase 9 (Angle A, continued) — the HASH case + the ~Copyable-element BOUNDARY
// Phase8 proved trees (flat A1, boxed A2/A2b) ride the D1 family default. Two pieces remain to evaluate
// Angle A's full claim ("span-projecting AND traversal-only, full ~Escapable/~Copyable element support"):
//   A3  HASH (separate-chaining, the supervisor's other named target) as a ~Escapable walker over a
//       FLATTENED value pool (Span<Int>) + bucket-boundary offsets — the A1 mechanism for a hash.
//   A4  the ~COPYABLE-ELEMENT BOUNDARY: can the D1 / Iterable makeIterator route yield ~Copyable
//       elements at all? (next() -> Element? returns BY VALUE; you cannot move a ~Copyable out of a
//       borrowed span.) This is the structural reason route-3 forEach exists; verified here, not asserted.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), arm64-apple-macosx26.0

// =====================================================================================
// MARK: A3 — hash (separate chaining) as a ~Escapable walker over a flattened value pool
// =====================================================================================
// Phase6's ToyHash is [[Int]] (array-of-arrays — no single span). But a hash's logical iteration is a
// flat sequence; store the chains END-TO-END in ONE [Int] pool with per-bucket (start,count) offsets,
// and the walker borrows that pool as Span<Int> — exactly A1's mechanism. (Real open-addressing /
// flat-chained hash tables already store this way.) This makes the hash SPAN-PROJECTING and rides D1.

public struct ToyFlatHash: ~Copyable {
    @usableFromInline var pool: [Int]          // all chain values, bucket 0 then bucket 1 then …
    @usableFromInline let bucketEnds: [Int]    // prefix-sum end offsets per bucket (logical order = pool order)
    @inlinable public init(pool: [Int], bucketEnds: [Int]) {
        self.pool = pool
        self.bucketEnds = bucketEnds
    }
}

// A ~Escapable walker borrowing the value pool as a Span (logical order == pool order, so a plain scan).
public extension Iterator {
    @frozen
    struct FlatHashChain<Element>: ~Escapable {
        @usableFromInline var pool: Span<Int>
        @usableFromInline var position: Int
        @usableFromInline let project: (Int) -> Element
        @_lifetime(copy pool)
        @inlinable public init(pool: consuming Span<Int>, project: @escaping (Int) -> Element) {
            self.pool = pool
            self.position = 0
            self.project = project
        }
    }
}

extension Iterator.FlatHashChain: Iterator.`Protocol` {
    @inlinable public mutating func next() -> Element? {
        guard position < pool.count else { return nil }
        defer { position &+= 1 }
        return project(pool[position])
    }
}

public extension Memory {
    @frozen
    struct FlatHashView: ~Copyable, ~Escapable {
        @usableFromInline let pool: Span<Int>
        @_lifetime(copy pool)
        @inlinable public init(pool: consuming Span<Int>) { self.pool = pool }
    }
}

extension Memory.FlatHashView: IterableByCopy {
    public typealias Element = Int
    public typealias Iterator = iteration_architecture_toy.Iterator.FlatHashChain<Int>
    @_lifetime(copy self)
    public borrowing func makeIterator() -> iteration_architecture_toy.Iterator.FlatHashChain<Int> {
        iteration_architecture_toy.Iterator.FlatHashChain(pool: pool) { $0 }
    }
}

extension ToyFlatHash: FamD.`Protocol` {
    public typealias Element = Int
    public typealias View = Memory.FlatHashView
    public var view: Memory.FlatHashView {
        @_lifetime(borrow self) get { Memory.FlatHashView(pool: pool.span) }
    }
    // bucketEnds retained to model real per-bucket structure; logical scan uses pool order directly.
}

// MARK: VERDICT (Angle A3) — CONFIRMED (compiles checker-clean + WARNING-CLEAN, runs in logical order
// [10,11,22,30,31,32], debug AND release). A separate-chaining HASH enters the D1 envelope by the SAME
// A1 mechanism: flatten the chains into ONE [Int] pool (logical order), expose it as a Span<Int>, and a
// ~Escapable walker (@_lifetime(copy pool)) scans it. Rides FamD.makeIteratorD1 with NO crash (the walker
// holds a REAL span, so it is in the A1/A2b happy case — unlike the immortal A2 boxed walker). So the
// "hash has no span" framing of Phase6 was about the [[Int]] REPRESENTATION, not the structure: real
// flat/open-addressed hashes are span-projecting and ride D1. (A boxed-chain hash with per-node ARC links
// and no value pool would be the immortal-walker case = A2's release-crash; use A2b's real-span workaround
// or route-3 forEach.)

// =====================================================================================
// MARK: A4 — the ~Copyable-element BOUNDARY for the D1 / Iterable (external-iterator) route
// =====================================================================================
// The base cursor is `mutating func next() -> Element?` (Iteration.swift) with Element: ~Copyable.
// For a span-borrowing walker, `return span[i]` for a ~Copyable Element must MOVE the element out of the
// borrowed span — which the span (a borrow) cannot allow. Hypothesis: the D1/Iterable EXTERNAL-iterator
// route CANNOT yield ~Copyable elements; only route-3 forEach (which LENDS via a borrowing closure param,
// never returns a value) can. VERIFIED — but the manifestation is a COMPILER CRASH, not a clean
// diagnostic (same bug family as A2):
//
//   struct CopyableSpanWalk: ~Escapable {            // Span<Resource> (~Copyable elements)
//       var span: Span<Resource>; var position: Int; @_lifetime(copy span) init(…) { … }
//   }
//   extension …: Iterator.`Protocol` {
//       typealias Element = Resource
//       mutating func next() -> Resource? {
//           guard position < span.count else { return nil }
//           defer { position &+= 1 }
//           return span[position]     // MOVE a ~Copyable out of a borrowed span
//       }
//   }
//
// Observed (verified, probe since removed): `swift build` (even DEBUG / -Onone) CRASHES at SILGen:
//   Abort: function forwardToInit at SILValue.h:375
//   Cannot initialize a nonCopyable type with a guaranteed value
//   While silgen emitFunction SIL function "@…CopyableSpanWalkProbeV4nextAA8ResourceVSgyF" for 'next()'
//   command (swift build)
// REDUCTION ([EXP-004]/[EXP-021], probes since removed), trigger isolated to the move-out:
//   • `next() -> Resource? { nil }` (no span access) → COMPILES CLEAN.
//   • `next() -> Int? { … return span[position].id }` (BORROW a Copyable field, no move) → COMPILES CLEAN.
//   • `next() -> Resource? { … return span[position] }` (MOVE the ~Copyable element out) → CRASHES (above).
//
// So the boundary is REAL (you cannot yield ~Copyable elements from a span-borrowing external iterator),
// and it currently CRASHES the compiler rather than diagnosing — a second face of the forwardToInit /
// "nonCopyable from guaranteed value" bug (A2 hits it in the release inliner; A4 hits it at SILGen).
// ARCHITECTURAL CONSEQUENCE (independent of the bug): Angle A's "external iterator" half is INHERENTLY
// Copyable-only by the LANGUAGE shape of next() (returns by value). ~Copyable elements MUST iterate via
// route-3 forEach (shape C), which LENDS (borrowing closure param) instead of returning. forEach is
// ALREADY a single family default (Family.swift / LibFamilies.swift) and ALREADY covers contiguous +
// non-contiguous (Phase6 b3). So the UNIFIED ~Copyable iteration vehicle is C, NOT D1 — exactly the
// v1.1.0 §4 "forEach unifies the copyability split for internal iteration" finding, here confirmed to
// extend to traversal-only (Angle C, Phase10).

// MARK: VERDICT (Angle A4) — REFUTED-for-D1 / CONFIRMED-for-C: the D1 external-iterator route cannot carry
// ~Copyable elements (next() returns by value → move-out of a borrowed span; here it CRASHES SILGen).
// ~Copyable iteration unifies under route-3 forEach (shape C), which is already one family default across
// span-projecting + traversal-only. D1 covers Copyable elements; C covers ~Copyable — across BOTH families.
