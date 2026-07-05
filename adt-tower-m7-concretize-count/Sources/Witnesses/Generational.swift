// (f) Generational-like witness — already element-domain (verbatim). Models the
//     slot-map / generational discipline whose live-element ledger is naturally in
//     the element domain: `count` is returned as-is, no retag (the M7 doc's
//     "the generational witness is already element-domain (verbatim)").

import SeamKit
import Index_Primitives

/// A generational slot-map whose live-element ledger is already element-domain.
public struct Generational: __M7BufferProtocol {
    public typealias Element = Int

    /// Live-element count, already in the element domain.
    public let liveCount: Index<Int>.Count

    @inlinable
    public init(live: UInt) {
        self.liveCount = Index<Int>.Count(live)
    }

    @inlinable
    public var count: Index<Int>.Count {
        liveCount
    }
    // `isEmpty` supplied by the unconstrained seam default.
}
