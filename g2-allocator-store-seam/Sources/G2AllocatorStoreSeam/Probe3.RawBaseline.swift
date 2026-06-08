// ===----------------------------------------------------------------------===//
//
// Probe 3 — raw baseline: each discipline as a `Memory.Allocator.`Protocol``.
//
// The raw seam is `allocate(count:alignment:) throws -> Memory.Address` +
// `deallocate(_:count:alignment:)`, with typing composed at the CALL SITE
// (`address.pointer.assumingMemoryBound(to:)`). This file gives a thin COMPILING
// reference for the bump arena on that seam, so the prose comparison in FINDINGS.md
// §(c)/(e) is grounded. (The full prose sketch lives in FINDINGS.md.)
//
// ===----------------------------------------------------------------------===//

public import Memory_Address_Primitives
public import Memory_Alignment_Primitives
public import Memory_Allocator_Protocol
import Memory_Primitive

// MARK: - Arena as a RAW allocator (the natural fit)

/// `G2.Arena` already HAS the bump shape (`bump(count:alignment:)`); conforming the
/// raw `Memory.Allocator.`Protocol`` is a near-identity wrap. This is the positive
/// counterpoint to Probe 2: the SAME arena that cannot be a `Store.`Protocol``
/// conforms to the raw allocator seam trivially and honestly.
extension G2.Arena: Memory.Allocator.`Protocol` {
    public typealias Error = Never

    public mutating func allocate(
        count: Memory.Address.Count,
        alignment: Memory.Alignment
    ) throws(Never) -> Memory.Address {
        // Bridge the typed count to the honest bump cursor. The alignment parameter
        // is part of the seam's shape; the bump arena rounds to its construction
        // alignment internally (16), which dominates the small elements used here.
        // (`bump` returns nil on exhaustion; a production seam would surface a typed
        // error via `Error` — the shape, not the error policy, is what this probe
        // demonstrates.)
        let bytes = Int(bitPattern: count)
        guard let address = bump(count: bytes, alignment: 16) else {
            fatalError("arena exhausted")
        }
        return address
    }

    public mutating func deallocate(
        _ address: Memory.Address,
        count: Memory.Address.Count,
        alignment: Memory.Alignment
    ) {
        // No-op: a bump arena reclaims only en masse (cf. the REAL `Memory.Arena`,
        // which witnesses `Memory.Allocator.`Protocol`` with the identical no-op
        // deallocate). This is the natural, honest definition — unlike the Store
        // seam's per-slot `move(at:)`, which has NO arena counterpart.
    }
}

// FINDING: raw baseline — see FINDINGS.md §(c) and §(e)
// ====================================================
//
// Arena → `Memory.Allocator.`Protocol``: NATURAL (this file compiles). The bump
// shape IS the raw allocator shape. Confirmed by the real ecosystem:
// `Memory.Arena` conforms to `Memory.Allocator.`Protocol`` directly with a no-op
// deallocate (swift-memory-arena-primitives/.../Memory.Arena.swift).
//
// Pool → `Memory.Allocator.`Protocol``: also natural but with a per-slot free path.
// The real `Memory.Pool` exposes exactly this raw shape
// (`allocate() -> UnsafeMutableRawPointer`, `deallocate(_:)`, `pointer(at:)`), with
// its doc stating outright: "Pool operates on untyped bytes. Typed access is
// composed at the call site." That is the raw baseline verbatim.
//
// RELATIVE COMPLEXITY (vs Probes 1–2):
//   - For ARENA: raw is STRICTLY SIMPLER and the ONLY honest option. Probe 2 showed
//     the typed Store cannot be witnessed at all. Raw wins outright.
//   - For POOL: raw and typed are comparable in mechanism, but they put the typing
//     burden in different places. Raw pushes `assumingMemoryBound(to:)` to EVERY
//     call site (unsafe, repeated, easy to get wrong); typed Store (Probe 1)
//     centralizes the typed slot surface ONCE in the conformer — at the cost of the
//     out-of-band occupancy oracle. For a homogeneous-element pool, the typed Store
//     is the better trade; for heterogeneous raw allocation, raw is the only option.
