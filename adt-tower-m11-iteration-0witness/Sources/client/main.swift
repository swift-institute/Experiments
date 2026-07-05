// MARK: - adt-tower-m11-iteration-0witness — D9/M11 iteration 0-witness re-verify ([EXP-017])
//
// Purpose:    Re-verify D9/M11 (Research/adt-tower.md §2 D9) as a fresh compiling
//             experiment against the REAL upstream columns: tower iteration flows from the
//             column as a borrowing `forEach` lending `(borrowing Element)`, 0-witness
//             cross-module, for BOTH buffer disciplines over a move-only element — with the
//             load-bearing Linear/Ring asymmetry (Linear ALSO vends the multipass `Iterable`
//             protocol; Ring vends ONLY the bespoke single-pass borrowing `forEach`, its
//             multipass `Iterable` having been active-pruned 2026-06-10).
//
// Hypothesis: Over a move-only `Job: ~Copyable`, a concrete `-O` client that
//               (1) counts via Linear's multipass `Iterable` path,
//               (2) sums via Linear's bespoke borrowing `forEach`,
//               (3) sums via Ring's bespoke borrowing `forEach`,
//             specializes to ZERO `witness_method` on every executing path. Any residual
//             `witness_method` lives ONLY inside the retained @inlinable generic
//             `Iterable.forEach` template (`public_external`, unreachable from the concrete
//             client).
//
// Toolchain:  Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
//             Target: arm64-apple-macosx26.0
// Platform:   macOS 26 (arm64)
//
// Result:     CONFIRMED — GREEN debug + release; runtime-correct (count=5, sum=19, all three
//             paths agree); `-O` client SIL carries 4 `witness_method` sites, ALL inside the
//             retained @inlinable generic `Iterable.forEach` template (`public_external`), and
//             0 in each of the three specialized client paths. Evidence:
//             Outputs/sil-witness-classification.txt.
//
// Date:       2026-07-05

import Buffer_Primitive
import Buffer_Protocol_Primitives
import Buffer_Linear_Primitive
import Buffer_Linear_Primitives          // brings the `Buffer.Linear: Iterable` conformance
import Buffer_Ring_Primitive
import Storage_Primitive
import Storage_Contiguous_Primitives
import Store_Protocol_Primitives
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Index_Primitives
import Iterable                          // multipass attachable + its generic `forEach` template

// MARK: - The move-only element

/// A move-only payload — the D9 `~Copyable` element under test. Needs only `~Copyable`:
/// the column build / append / push / borrowing-iterate surface asks nothing more of it.
struct Job: ~Copyable {
    var priority: Int
    init(_ priority: Int) { self.priority = priority }
}

// MARK: - Concrete column front doors (REAL Linear + Ring columns over the heap allocator)

typealias JobStorage = Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Job>
typealias LinearJobs = Buffer<JobStorage>.Linear
typealias RingJobs   = Buffer<JobStorage>.Ring

// MARK: - Path (1): count via Linear's multipass `Iterable` protocol path
//
// Dispatched THROUGH the `Iterable` protocol (generic over any Iterable column), NOT the
// concrete bespoke `Buffer.Linear.forEach` — this forces the protocol-vended multipass
// surface. Under `-O` this specializes for the concrete Linear column: the generic
// @inlinable `Iterable.forEach` devirtualizes to the concrete chunk iterator, leaving the
// retained generic template `public_external` and unreachable from this concrete client.
@inline(never)
func countViaIterable<C: Iterable & ~Copyable & ~Escapable>(_ column: borrowing C) -> Int
where C.Iterator.Failure == Never {
    var n = 0
    column.forEach { (_: borrowing C.Iterator.Element) in n += 1 }
    return n
}

// MARK: - Path (2): sum via Linear's bespoke borrowing `forEach`
//
// `Buffer.Linear.forEach` (Buffer.Linear+forEach.swift) — a fully concrete borrowing terminal;
// no protocol dispatch at all.
@inline(never)
func sumViaLinearForEach(_ column: borrowing LinearJobs) -> Int {
    var total = 0
    column.forEach { (job: borrowing Job) in total += job.priority }
    return total
}

// MARK: - Path (3): sum via Ring's bespoke borrowing `forEach`
//
// `Buffer.Ring.forEach` (Buffer.Ring+forEach.swift) — the ONLY iteration surface Ring vends
// for a move-only element (its multipass `Iterable` was pruned). Ledger-walked
// `storage[slot]` subscript; concrete.
@inline(never)
func sumViaRingForEach(_ ring: borrowing RingJobs) -> Int {
    var total = 0
    ring.forEach { (job: borrowing Job) in total += job.priority }
    return total
}

// MARK: - Build real columns, fill with Jobs, iterate, print

let priorities = [5, 1, 3, 8, 2]        // expected count = 5, expected sum = 19

// The runtime-Int capacity: `Index<Job>.Count(_: Int)` validates non-negativity and so
// throws (the SLI runtime-int path, distinct from the non-throwing integer-literal path).
let capacity = try Index<Job>.Count(priorities.count)

// Real Linear column.
var linear = LinearJobs(minimumCapacity: capacity)
for p in priorities { linear.append(Job(p)) }

// Real Ring column.
var ring = RingJobs(minimumCapacity: capacity)
for p in priorities { ring.push.back(Job(p)) }

let linearCount = countViaIterable(linear)          // (1) Linear multipass `Iterable` path
let linearSum   = sumViaLinearForEach(linear)       // (2) Linear bespoke borrowing `forEach`
let ringSum     = sumViaRingForEach(ring)           // (3) Ring bespoke borrowing `forEach`

// Formatting note: use the CONCRETE `Int.description` (a direct call) rather than
// `\(intValue)` string interpolation. Interpolation leaves a residual
// `witness_method $Int, #CustomStringConvertible.description` in `@main` (print machinery,
// not tower iteration) — routing through `.description` keeps `@main` witness-free so the
// SIL residual is EXACTLY the Iterable.forEach template, matching the D9 receipt.
print("linear-iterable-count: " + linearCount.description)
print("linear-foreach-sum: " + linearSum.description)
print("ring-foreach-sum: " + ringSum.description)

// Runtime-correctness gate. Literal expected values + StaticString messages (no
// interpolation) keep the gate witness-free too.
precondition(linearCount == 5, "Linear Iterable count mismatch")
precondition(linearSum == 19, "Linear forEach sum mismatch")
precondition(ringSum == 19, "Ring forEach sum mismatch")
print("OK: count=5 sum=19 (all three iteration paths agree)")
