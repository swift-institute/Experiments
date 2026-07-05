// (c) Slab-like witness (Static) — native ledger is Bit-domain (`Bit.Index.Count`,
//     matching the real Buffer.Slab.Header bitmap-popcount occupancy). Re-tags to
//     the element domain via the sanctioned in-tree `.retag(Element.self)` idiom
//     (one occupied bitmap slot IS one live element — a phantom-label change,
//     numerically sound; cf. Buffer.Slab+Operations.swift:20 `.retag(Bit.self)`).

import SeamKit
import Index_Primitives
import Bit_Index_Primitives

/// A sparse slab whose native occupancy ledger counts in the bitmap (Bit) domain.
public struct SlabStatic: __M7BufferProtocol {
    public typealias Element = Int

    /// Native ledger: occupied bitmap slots, in the Bit domain.
    public let occupancy: Bit.Index.Count

    @inlinable
    public init(occupied: UInt) {
        self.occupancy = Bit.Index.Count(occupied)
    }

    /// M7 conformer cost: re-tag the Bit-domain occupancy into the element domain.
    /// `Tagged<Bit, Cardinal>.retag(Int.self)` → `Tagged<Int, Cardinal>` = `Index<Int>.Count`.
    @inlinable
    public var count: Index<Int>.Count {
        occupancy.retag(Element.self)
    }
    // `isEmpty` supplied by the unconstrained seam default.
}
