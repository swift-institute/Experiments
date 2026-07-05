// (b) Ring-like witness — derives count from head/tail cursors (typed indices),
//     already in the element domain. Models the Ring discipline: occupancy is a
//     computed distance, not a stored ledger.

import SeamKit
import Index_Primitives

/// A ring buffer whose count is derived from head/tail element-domain cursors.
public struct Ring: __M7BufferProtocol {
    public typealias Element = Int

    /// Element-domain read cursor.
    public let head: Index<Int>
    /// Element-domain write cursor.
    public let tail: Index<Int>

    @inlinable
    public init(head: UInt, tail: UInt) {
        self.head = Index<Int>(_unchecked: Ordinal(head))
        self.tail = Index<Int>(_unchecked: Ordinal(tail))
    }

    /// Live-element count = tail − head, in the element domain. No retag: both
    /// cursors are already `Index<Int>` (`Tagged<Int, Ordinal>`), so the derived
    /// count is `Index<Int>.Count` (`Tagged<Int, Cardinal>`) by construction.
    @inlinable
    public var count: Index<Int>.Count {
        Index<Int>.Count(tail.underlying.rawValue - head.underlying.rawValue)
    }
    // `isEmpty` supplied by the unconstrained seam default.
}
