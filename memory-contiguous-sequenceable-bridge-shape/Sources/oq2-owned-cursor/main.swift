// MARK: - OQ-2: Escapable owned cursor vended from consuming Sequenceable.makeIterator
//
// Purpose: validate the revised §1 shape in
//   swift-institute/Research/memory-contiguous-iteration-bridge.md.
//   The memory->Sequenceable bridge vends an OWNED cursor (the W1-owned sibling deferred by
//   cursor-shape-a-vs-three-worlds.md) conforming to the foundation Iterator.`Protocol`. Because
//   the bridge owns an Escapable contiguous base, the cursor is ESCAPABLE (vs the borrowed
//   Cursor's unconditional ~Escapable). The risk: Sequenceable requires
//   `@_lifetime(copy self) consuming func makeIterator() -> Iterator`, and the Sequenceable doc
//   warns `@_lifetime` is rejected on an Escapable result. Does an Escapable-iterator witness
//   satisfy the requirement?
// Hypothesis: it typechecks (the owned-cursor sibling shape is expressible).
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108)
// Platform: macOS 26 (arm64)
// Result: CONFIRMED (V2a). An Escapable owned cursor conforming Iterator.`Protocol`, vended from
//   `consuming func makeIterator()`, typechecks WHEN @_lifetime is OMITTED. Build Succeeded debug
//   (4.52s) + release (3.68s); run => total = 60.
//   V1 (Escapable result WITH @_lifetime) REFUTED: "error: invalid lifetime dependence on an
//   Escapable result" / "...on an Escapable value with consuming ownership" (on both next() and
//   makeIterator). So: the owned cursor IS Escapable (as the principal predicted) AND omits
//   @_lifetime — Swift accepts the Escapable witness against the @_lifetime-annotated protocol
//   requirements. (Cross-module axis deferred to execution per [EXP-017].)
// Date: 2026-05-27

import Sequence_Protocol_Primitives
import Iterator_Primitives

// An OWNED, Escapable scalar cursor: owns its base by value, yields elements one at a time by
// copy-out. Mirrors the bridge's iterator (owns the consumed contiguous Self; re-derives the
// element view inside next(), never storing a ~Escapable span). Here the base is a plain
// Escapable+Copyable `[Int]` so the lifetime question is isolated from Memory.Contiguous detail.
struct OwnedCursor: Iterator.`Protocol` {
    var base: [Int]          // OWNS the consumed base
    var position: Int
    typealias Element = Int
    typealias Failure = Never

    init(_ base: consuming [Int]) {
        self.base = base
        self.position = 0
    }

    // V2a: Escapable result => @_lifetime is invalid (V1); omit it and test whether an
    // Escapable-iterator witness still satisfies Iterator.`Protocol`'s @_lifetime(&self) next().
    mutating func next() -> Int? {
        guard position < base.count else { return nil }
        defer { position += 1 }
        return base[position]   // copy-out: Element: Copyable & Escapable
    }
}

// A minimal Sequenceable whose Iterator is the Escapable owned cursor.
struct Region: Sequenceable {
    var elements: [Int]
    typealias Element = Int
    typealias Iterator = OwnedCursor

    // V2a: omit @_lifetime here too (Escapable OwnedCursor result). Does the witness still
    // satisfy Sequenceable's `@_lifetime(copy self) consuming func makeIterator()`?
    consuming func makeIterator() -> OwnedCursor {
        OwnedCursor(elements)
    }
}

// Exercise it: makeIterator (consuming) + scalar next() loop.
var iterator = Region(elements: [10, 20, 30]).makeIterator()
var total = 0
while let x = iterator.next() { total += x }
print("OQ-2: total = \(total) (expect 60)")
