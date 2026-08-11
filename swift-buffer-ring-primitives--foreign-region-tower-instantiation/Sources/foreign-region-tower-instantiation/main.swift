// MARK: - Foreign-Region Tower Instantiation
// Purpose: Verify whether a Foreign-shaped memory regime — adopted, not allocated;
//          released by a caller-supplied finalizer, never by deallocate — slots into
//          the MSB tower (Memory -> Storage -> Buffer) with zero tier-2/tier-3 changes.
// Hypothesis (Memory.Foreign research brief, 2026-06-12): "if Memory.Foreign satisfies
//          whatever Storage.Contiguous requires of its memory parameter, then
//          Buffer<Storage<...>.Contiguous<Memory.Foreign>>.Ring (etc.) exists with
//          zero changes to tiers 2-4."
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101)
// Platform: arm64-apple-macosx26.0
//
// Result: PARTIAL — hypothesis CONFIRMED at the Storage tier, REFUTED at the Buffer tier.
//   V1 CONFIRMED — a ~Copyable finalizer-deinit struct conforms Memory.Region with two
//      properties (base + capacity); nothing in the seam asks who allocated or how to free.
//      Output: "V1 foreign region conforms Memory.Region: CONFIRMED"
//   V2 CONFIRMED — Storage<Foreign>.Contiguous<UInt8> constructs via the EXISTING
//      Memory.Region convenience init (Storage.Contiguous.swift:100-111), the 4-op seam
//      reads/writes/moves, and the drop cascade runs oracle-then-finalizer EXACTLY once.
//      Output: "V2 ... finalizer invocations = 1: CONFIRMED" (zero tier-2 changes)
//   V3 CONFIRMED — one generic function over S: Store.Ledgered.`Protocol` HAND-REPLAYS the
//      ring discipline's storage-interaction pattern (initialize/move + arbitrary-slot
//      ledger overwrite) over BOTH the heap column and the foreign column; identical
//      output [10,11,12,13,14,15] from both substrates. Scope: V3 proves the seam
//      suffices for the ops' INTERACTION PATTERN; it does NOT compile the actual
//      (pinned — see V4) static-op bodies against the foreign substrate. The definitive
//      receipt is a one-op where-clause relaxation compile (tower-program artifact).
//   V4 REFUTED (the zero-tier-3-changes claim) — every public Buffer.Ring entry point
//      refuses the foreign substrate at compile time. Diagnostics captured:
//      -DNEGATIVE_PROBE_CREATE  : "referencing static method 'create(minimumCapacity:)' on
//                                  'Storage.Contiguous' requires the types 'Foreign' and
//                                  'Memory.Allocator<Memory.Heap>.System' be equivalent"
//                                  (create exists only on the heap column,
//                                  Storage.Contiguous.swift:149-164)
//      -DNEGATIVE_PROBE_BOUNDED : "cannot convert parent type 'Storage<Foreign>' to expected
//                                  type 'Storage<Memory.Allocator<Memory.Heap>.System>'"
//                                  (the only public Bounded init is heap-pinned,
//                                  Buffer.Ring.Bounded+Operations.swift:13)
//      -DNEGATIVE_PROBE_PUSH    : "cannot convert parent type 'Storage<Foreign>' to expected
//                                  type 'Storage<Memory.Allocator<Memory.Heap>.System>'"
//                                  (push view ops heap-pinned, Buffer.Ring.Bounded.Push.swift:11-15)
//   V5 (sibling target `foreign-region-sending`, ecosystem settings incl.
//      .strictMemorySafety()): the v1.1.0 concurrency posture — no Sendable
//      conformance, plain (non-@Sendable) finalizer, isolation crossing via
//      region-based `sending` — CONFIRMED both directions; see that target's header.
// Date: 2026-06-12

import Memory_Primitives
import Memory_Heap_Primitives
import Memory_Allocation_Primitives
import Store_Primitives
import Storage_Primitives
import Index_Primitives
import Buffer_Primitives
import Buffer_Ring_Bounded_Primitives

// MARK: - Variant 1: the Foreign-shaped regime
// Hypothesis: a ~Copyable struct owning memory it did NOT allocate, releasing via a
// caller-supplied finalizer in deinit, can conform Memory.Region (base + capacity only).

/// Counts finalizer invocations so the exactly-once law is checkable from outside.
final class FinalizerWitness {
    var invocations = 0
}

/// A Foreign-shaped memory regime: a located run of raw bytes this process did not
/// allocate (simulated below by a detached allocation standing in for, e.g., an
/// io_uring provided buffer), owned past the lending scope, released by invoking a
/// caller-supplied finalizer — never by deallocate.
struct Foreign: ~Copyable {
    let buffer: UnsafeMutableRawBufferPointer
    let finalizer: (UnsafeMutableRawBufferPointer) -> Void

    init(
        adopting buffer: UnsafeMutableRawBufferPointer,
        finalizer: @escaping (UnsafeMutableRawBufferPointer) -> Void
    ) {
        self.buffer = buffer
        self.finalizer = finalizer
    }

    deinit { finalizer(buffer) }
}

extension Foreign: Memory.Region {
    var base: Memory.Address { Memory.Address(buffer.baseAddress!) }
    var capacity: Memory.Address.Count { Memory.Address.Count(UInt(buffer.count)) }
}

print("V1 foreign region conforms Memory.Region: CONFIRMED")

// MARK: - Variant 2: the Storage tier composes over Foreign (zero tier-2 changes)
// Hypothesis: Storage<Foreign>.Contiguous<UInt8> constructs through the EXISTING
// Memory.Region convenience init, the 4-op seam works, and dropping the storage runs
// oracle-then-finalizer exactly once.

func variant2() -> Int {
    let witness = FinalizerWitness()
    do {
        let raw = UnsafeMutableRawBufferPointer.allocate(byteCount: 8, alignment: 8)
        let foreign = Foreign(adopting: raw) { [witness] buf in
            buf.deallocate()
            witness.invocations += 1
        }
        var storage = Storage<Foreign>.Contiguous<UInt8>(allocation: foreign, capacity: 8)
        storage.initialize(at: 0, to: 0xA0)
        storage.initialize(at: 1, to: 0xA1)
        let read = storage[0]
        let moved = storage.move(at: 1)
        precondition(read == 0xA0 && moved == 0xA1, "seam read/move over foreign region")
        // storage drops here: ledger oracle deinitializes the live slot, THEN the
        // Foreign field's deinit runs the finalizer.
    }
    return witness.invocations
}

let v2Invocations = variant2()
precondition(v2Invocations == 1, "finalizer must run exactly once")
print("V2 Storage<Foreign>.Contiguous via Memory.Region init, finalizer invocations = \(v2Invocations): CONFIRMED")

// MARK: - Variant 3: the ring discipline's storage interactions are substrate-generic
// Hypothesis: the static ops' bodies (Buffer.Ring+Memory.Heap ~Copyable.swift:8-13 says
// they "use ONLY the inherited element-store surface ... therefore generic over any
// S: Store.`Protocol`") really do generalize: one generic function constrained to the
// NAMED capability Store.Ledgered.`Protocol` (ratified 2026-06-10) drives a wrapped
// ring exercise over both the heap column and the foreign column.

func wrapAroundExercise<S>(_ storage: inout S) -> [UInt8]
where S: Store.Ledgered.`Protocol`, S: ~Copyable, S.Element == UInt8 {
    var out: [UInt8] = []
    // fill four slots (capacity 4)
    storage.initialize(at: 0, to: 10)
    storage.initialize(at: 1, to: 11)
    storage.initialize(at: 2, to: 12)
    storage.initialize(at: 3, to: 13)
    // pop two from the front, push two at the wrapped physical slots 0,1
    out.append(storage.move(at: 0))
    out.append(storage.move(at: 1))
    storage.initialize(at: 0, to: 14)
    storage.initialize(at: 1, to: 15)
    // the wrapped occupancy is no longer prefix-shaped: overwrite the self-maintained
    // ledger with the computed shape — the Store.Ledgered contract for arbitrary-slot
    // disciplines (the ring's sync invariant).
    storage.initialization = .linear(count: 4)
    // drain in ring (FIFO) order
    out.append(storage.move(at: 2))
    out.append(storage.move(at: 3))
    out.append(storage.move(at: 0))
    out.append(storage.move(at: 1))
    storage.initialization = .empty
    return out
}

let expected: [UInt8] = [10, 11, 12, 13, 14, 15]

var heapColumn = Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<UInt8>.create(minimumCapacity: 4)
let heapOut = wrapAroundExercise(&heapColumn)
precondition(heapOut == expected, "heap column ring exercise")

let v3Witness = FinalizerWitness()
do {
    let raw = UnsafeMutableRawBufferPointer.allocate(byteCount: 4, alignment: 8)
    let foreign = Foreign(adopting: raw) { [v3Witness] buf in
        buf.deallocate()
        v3Witness.invocations += 1
    }
    var foreignColumn = Storage<Foreign>.Contiguous<UInt8>(allocation: foreign, capacity: 4)
    let foreignOut = wrapAroundExercise(&foreignColumn)
    precondition(foreignOut == expected, "foreign column ring exercise")
}
precondition(v3Witness.invocations == 1, "foreign column finalizer exactly once")
print("V3 one generic ring exercise over heap AND foreign columns, output \(heapOut): CONFIRMED")

// MARK: - Variant 4 (negative probes; build with -Xswiftc -D<FLAG>)
// Hypothesis: the Buffer tier's public entry points refuse the foreign substrate at
// compile time because every op/init is same-type-pinned to the heap column.

#if NEGATIVE_PROBE_CREATE
// Expected: error — `create` exists only where Allocation == Memory.Allocator<Memory.Heap>.System
// (Storage.Contiguous.swift:149-164). Foreign memory rightly cannot be allocated-to-size.
let cannotCreate = Storage<Foreign>.Contiguous<UInt8>.create(minimumCapacity: 4)
#endif

#if NEGATIVE_PROBE_BOUNDED
// Expected: error — the only PUBLIC Bounded initializer is heap-pinned
// (Buffer.Ring.Bounded+Operations.swift:13); the substrate-generic init is package-scoped
// (Buffer.Ring.Bounded.swift:26).
var cannotInit = Buffer<Storage<Foreign>.Contiguous<UInt8>>.Ring.Bounded(minimumCapacity: 4)
#endif

#if NEGATIVE_PROBE_PUSH
// Expected: error — the push view's `back` exists only on the heap-pinned
// Property.Inout.Typed extension (Buffer.Ring.Bounded.Push.swift:11-15).
func pushProbe(_ ring: inout Buffer<Storage<Foreign>.Contiguous<UInt8>>.Ring.Bounded) {
    ring.push.back(7)
}
#endif

print("done")
