// (e) Slab-like witness (Small) — Bit-domain ledger, element-domain via retag.
//     Third of the three slab witnesses; mirrors Buffer.Slab.Small (inline
//     small-capacity slot storage) whose header occupancy is likewise Bit-domain.

import SeamKit
import Index_Primitives
import Bit_Index_Primitives

/// A small (inline) slab; occupancy ledger counts in the bitmap (Bit) domain.
public struct SlabSmall: __M7BufferProtocol {
    public typealias Element = Int

    /// Native ledger: occupied bitmap slots, in the Bit domain.
    public let occupancy: Bit.Index.Count

    @inlinable
    public init(occupied: UInt) {
        self.occupancy = Bit.Index.Count(occupied)
    }

    @inlinable
    public var count: Index<Int>.Count {
        occupancy.retag(Element.self)
    }
    // `isEmpty` supplied by the unconstrained seam default.
}
