// Consumer — exercises the V1 sketch and the V2 alternative ACROSS A MODULE BOUNDARY ([EXP-017]).
import Seam

// V1 — the sketch: ArrayADT over a concrete LinearBuffer; subscript reaches B.Storage.
var a = ArrayADT(buffer: LinearBuffer(storage: HeapStore([10, 20, 30]), count: 3))
print("V1 count=\(a.count) a[1]=\(a[1])")     // reaches buffer.storage[1] through the assoc-type
a[1] = 99
print("V1 after set a[1]=\(a[1])")

// V2 — ride-the-buffer alternative (single-protocol constraint).
print("V2 ridingCount=\(a.ridingCount)")

// V3 REFUTED (see Seam.swift): `B.Storage.Element: ~Copyable` can't be re-suppressed; clause unnecessary.
