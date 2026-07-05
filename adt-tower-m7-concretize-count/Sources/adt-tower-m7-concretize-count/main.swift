// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-institute Experiments corpus.
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - adt-tower-m7-concretize-count
//
// Purpose:   Re-verify the M7 seam amendment (Research/adt-tower.md §4.2
//            [DS-025]/[DS-026]) as a fresh compiling experiment. M7 DELETES
//            `associatedtype Count` from the observability seam
//            `Buffer.Protocol` (`__BufferProtocol`) and vends the CONCRETE
//            `count: Index<Element>.Count` (`Element: ~Copyable` the only
//            associated type left); the `isEmpty` default becomes UNCONSTRAINED
//            (`count == .zero` compiles because concrete `Index<Element>.Count`
//            = `Tagged<Element, Cardinal>` surfaces `==` and `.zero`).
//
// Hypothesis: (1) The concretized seam + unconstrained `isEmpty` default compile
//            against the REAL atomic packages. (2) Six conformers modeled on the
//            production witness shapes conform — dense/element-domain verbatim;
//            Bit-domain slab witnesses re-tag via `.retag(Element.self)`. (3) A
//            slab witness returning its Bit-domain count WITHOUT retag is REJECTED
//            (the concrete-Count constraint is load-bearing). (4) The seam target
//            needs NO direct Carrier_Protocol / Cardinal_Primitive import.
//
// Toolchain: swift-driver version: 1.148.6 Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
//            Target: arm64-apple-macosx26.0
// Platform:  macOS 26 (arm64)
//
// Result:    CONFIRMED
//   Evidence:
//     - Build Succeeded (debug + release): `swift build`, `swift build -c release`
//       both zero errors — see Outputs/build.txt, Outputs/release-mode-pass.txt.
//     - Cross-module: this executable → Witnesses → SeamKit; the generic
//       `report(_:_:)` below dispatches `count`/`isEmpty` across two module
//       boundaries with `Element: ~Copyable` suppression ([EXP-017]) —
//       see Outputs/cross-module-pass.txt.
//     - Runtime (Outputs/run.txt): dense/ring/generational report element-domain
//       counts verbatim; the three slab witnesses report retagged Bit→element
//       counts; empty witnesses report isEmpty=true.
//     - Negative control (Outputs/negative-control.txt): the non-retag slab
//       witness is REJECTED — "cannot convert return expression of type
//       'Bit.Index.Count' (aka 'Tagged<Bit, Cardinal>') to return type
//       'Index<Int>.Count' (aka 'Tagged<Int, Cardinal>')".
//     - Dep-surface: SeamKit imports ONLY Index_Primitives under
//       InternalImportsByDefault + MemberImportVisibility and compiles — the M7
//       secondary-win claim holds under strict conditions.
//
// Boundary ([EXP-020]): proves the DESIGN (concretized seam + real atomic-type
//   packages). Does NOT prove the production seam change — W1.7 additionally
//   requires the same green against the REAL slab / slot-map / generational
//   packages. Design-proven, not production-proven.
//
// Date: 2026-07-05

import SeamKit
import Witnesses
import Index_Primitives

// MARK: - Generic seam consumer (cross-module, ~Copyable-suppressed)

/// Observe a buffer through the concretized seam. Generic over any conformer with
/// a `~Copyable` element — exercises the M7 concrete `count` and the unconstrained
/// `isEmpty` default across the module boundary.
///
/// `B.Element` inherits `~Copyable` from the seam's `associatedtype Element: ~Copyable`:
/// it is NOT re-suppressed in a where clause (Swift rejects re-suppressing an
/// associated type from an outer scope — "cannot suppress '~Copyable' on generic
/// parameter 'B.Element'"). Leaving `B.Element` unconstrained keeps it
/// ~Copyable-capable, so this function admits conformers with noncopyable elements;
/// the body never copies an element (it reads only the Copyable `count`/`isEmpty`).
func report<B: __M7BufferProtocol & ~Copyable & ~Escapable>(
    _ label: String,
    _ buffer: borrowing B
) {
    // `count` is the concrete `Index<Element>.Count` (= `Tagged<Element, Cardinal>`);
    // `.underlying.rawValue` unwraps to the raw UInt for display.
    let raw = buffer.count.underlying.rawValue
    print("\(label): count=\(raw) isEmpty=\(buffer.isEmpty)")
}

// MARK: - Drive every conformer through the seam

print("== M7 concretized seam — conformers observed through the generic seam ==")

// (a) dense/element-domain, stored verbatim
report("Linear(4)      ", Linear(elements: 4))
report("Linear(empty)  ", Linear(elements: 0))

// (b) ring, count derived from element-domain head/tail cursors
report("Ring[2,7)      ", Ring(head: 2, tail: 7))
report("Ring(empty)    ", Ring(head: 5, tail: 5))

// (c–e) slab family: Bit-domain ledger re-tagged into the element domain
report("SlabStatic(3)  ", SlabStatic(occupied: 3))
report("SlabBounded(5) ", SlabBounded(occupied: 5, capacity: 16))
report("SlabSmall(0)   ", SlabSmall(occupied: 0))

// (f) generational, already element-domain (verbatim)
report("Generational(9)", Generational(live: 9))

print("== done ==")
