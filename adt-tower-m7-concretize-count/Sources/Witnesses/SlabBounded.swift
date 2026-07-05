// (d) Slab-like witness (Bounded) — Bit-domain ledger, element-domain via retag.
//     Second of the three slab witnesses (Static / Bounded / Small) that mirror the
//     real swift-buffer-slab-primitives family, each counting in `Bit.Index.Count`.

import SeamKit
import Index_Primitives
import Bit_Index_Primitives

/// A capacity-bounded slab; occupancy ledger counts in the bitmap (Bit) domain.
public struct SlabBounded: __M7BufferProtocol {
    public typealias Element = Int

    /// Native ledger: occupied bitmap slots, in the Bit domain.
    public let occupancy: Bit.Index.Count
    /// Fixed slot capacity (Bit domain), retained to model the bounded shape.
    public let capacity: Bit.Index.Count

    @inlinable
    public init(occupied: UInt, capacity: UInt) {
        self.occupancy = Bit.Index.Count(occupied)
        self.capacity = Bit.Index.Count(capacity)
    }

    @inlinable
    public var count: Index<Int>.Count {
        occupancy.retag(Element.self)
    }
    // `isEmpty` supplied by the unconstrained seam default.
}
