// MARK: - adt-tower-m8-ownership-shared-rehome — the H1 runtime leg ([EXP-017] cross-module)
//
// Purpose:    Re-verify the M8 (W1.8) MECHANISM from Research/adt-tower.md §D4.5: the CoW column
//             re-homed as a generic struct nested in the REAL `Ownership` namespace via a
//             CROSS-PACKAGE extension (`extension Ownership { public struct Rehomed<…> }`),
//             wrapping the real `Ownership.Box` drain-box ([MEM-SAFE-028]), and prove CoW
//             semantics hold at runtime over a real direct heap-linear column.
//
// Hypothesis: H1 (positive) — a faithful copy of the real CoW column source, re-homed into
//             `Ownership` cross-package under a non-colliding name (`Rehomed`) against the REAL
//             swift-ownership-primitives + the real storage/buffer/index stack, compiles
//             debug+release AND CoW semantics hold: two handles share until mutation; mutation
//             on a non-unique handle copies; a unique handle mutates in place.
//
// Toolchain:  swift-driver version: 1.148.6 Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
//             Target: arm64-apple-macosx26.0
// Platform:   macOS 26 (arm64)
//
// Result:     CONFIRMED — compiles debug AND release, cross-module (RehomeKit -> this executable),
//             identical output both configs. CoW evidence ([EXP-006b]):
//               a (initial): [10, 20, 30]  · a.isUnique (sole owner): true
//               after copy — same box: true · a.isUnique while shared: false · b.isUnique while shared: false
//               after mutation — boxes diverged: true · a.isUnique after divergence: true · b.isUnique after divergence: true
//               a (unchanged): [10, 20, 30] · b (mutated): [10, 20, 30, 99]
//             The re-home wraps the real `Ownership.Box` (the drain-box is untouched); the
//             `_boxID` (ObjectIdentifier of the box backing) is equal while shared and diverges
//             after the non-unique handle mutates — the observable CoW detach.
//
// Date:       2026-07-05

import RehomeKit
import Ownership_Primitive
import Ownership_Box_Primitives
import Buffer_Primitive
import Buffer_Linear_Primitive
import Storage_Primitive
import Storage_Contiguous_Primitives
import Memory_Heap_Primitives
import Memory_Allocator_Primitive
import Memory_Allocator_Protocol_Primitives
import Index_Primitives

// The real direct column swift-shared-primitives itself wraps: the dense heap-linear buffer stack.
typealias Column = Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Linear
typealias Col = Ownership.Rehomed<Int, Column>

/// Reads the live elements through the re-homed column's `Store.Protocol` seam subscript.
func elements(_ r: borrowing Col) -> [Int] {
    var out: [Int] = []
    let n = Int(r.count.underlying.rawValue)
    var i = 0
    while i < n {
        out.append(r[Index(Ordinal(UInt(i)))])
        i += 1
    }
    return out
}

print("=== H1: CoW semantics over the cross-package re-homed Ownership.Rehomed column ===")

// Build a shared (Copyable-element -> CoW-capable) column and fill it through the CoW surface.
var a = Col(Column(minimumCapacity: Index<Int>.Count(4)))
a.append(10)
a.append(20)
a.append(30)
print("a (initial):", elements(a))
print("a.isUnique (sole owner):", a.isUnique)

// Copy: shares the refcounted box, no payload copy yet.
var b = a
let idA1 = a._boxID
let idB1 = b._boxID
print("after copy — same box:", idA1 == idB1)
print("a.isUnique while shared:", a.isUnique)
print("b.isUnique while shared:", b.isUnique)

// Mutate the NON-UNIQUE handle: ensureUnique() must clone -> the box backing diverges.
b.append(99)
let idA2 = a._boxID
let idB2 = b._boxID
print("after mutation — boxes diverged:", idA2 != idB2)
print("a.isUnique after divergence:", a.isUnique)
print("b.isUnique after divergence:", b.isUnique)

// Divergence is value-level, not just identity: a is unchanged, b carries the append.
print("a (unchanged):", elements(a))
print("b (mutated):", elements(b))

// A unique handle mutates in place (no clone, box identity stable across the append).
var c = Col(Column(minimumCapacity: Index<Int>.Count(4)))
c.append(1)
let idC1 = c._boxID
c.append(2)
let idC2 = c._boxID
print("unique-handle in-place (box stable):", idC1 == idC2, "->", elements(c))

// Verdict line (asserted so a regression fails the run, not just the eye).
let h1Pass =
    elements(a) == [10, 20, 30] &&
    elements(b) == [10, 20, 30, 99] &&
    idA1 == idB1 &&        // shared before mutation
    idA2 != idB2 &&        // diverged after mutation
    idC1 == idC2           // unique handle stays in place
precondition(h1Pass, "H1 CoW semantics regression")
print("H1 VERDICT: CONFIRMED")
