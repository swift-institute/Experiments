// ===----------------------------------------------------------------------===//
//
// g2-seam-run — exercises the probes at runtime.
//
// Probe 1 (Pool) round-trips through allocate + the Store seam, with sparsity.
// Probe 1b / Probe 2 are type-level / negative results (see their FINDING blocks)
// and are driven only to confirm they execute without UB where they compile.
//
// ===----------------------------------------------------------------------===//

import G2AllocatorStoreSeam

let poolResult = G2.drivePool()
print("Probe 1 (Pool as Store) — observed ids:", poolResult)
precondition(
    poolResult == [100, 101, 102, 100, 200],
    "Pool Store-seam round-trip mismatch: \(poolResult)"
)

G2.denseOverSparse()
print("Probe 1b (Storage.Contiguous<Pool>) — dense-over-sparse type-checked and ran the one-slot path.")

var arena = G2.Arena(capacityBytes: 256)
let a = arena.bump(count: 8, alignment: 8)
print("Probe 2 (Arena) — bump(8) returned an address:", a != nil)
print("Probe 2 — Arena conforms to Memory.Allocator.Protocol (Probe 3), NOT Store.Protocol.")

print("OK")
