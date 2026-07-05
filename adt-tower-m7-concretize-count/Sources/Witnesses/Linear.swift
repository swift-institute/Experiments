// (a) Linear-like witness — native occupancy is already the element domain,
//     held directly as `Index<Element>.Count`. Models the dense Linear/Aligned/
//     Unbounded/Arena disciplines: `count` is stored/returned verbatim, no retag.

import SeamKit
import Index_Primitives

/// A dense buffer whose count is stored directly in the element domain.
public struct Linear: __M7BufferProtocol {
    public typealias Element = Int

    /// Element-domain occupancy, held verbatim.
    public let count: Index<Int>.Count

    @inlinable
    public init(count: Index<Int>.Count) {
        self.count = count
    }

    /// Convenience: construct from a raw element count.
    @inlinable
    public init(elements: UInt) {
        self.count = Index<Int>.Count(elements)
    }
    // `isEmpty` supplied by the unconstrained seam default.
}
