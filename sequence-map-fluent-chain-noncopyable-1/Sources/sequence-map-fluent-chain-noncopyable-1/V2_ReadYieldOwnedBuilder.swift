// V2 — `_read` coroutine yielding a Builder that OWNS Base.
//
// Hypothesis: A `_read` accessor borrows self for the yield. To yield
// a Builder<Self> that OWNS Self, we'd need to move Self into the
// Builder during the borrow, which is impossible.
//
// Expected verdict: STRUCTURALLY IMPOSSIBLE. Either compile-time
// rejection or a forced workaround that re-introduces consume semantics.

public struct V2_BuilderOwned<Base: SeqProtocol & ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    @usableFromInline
    var _base: Base

    @_lifetime(copy _base)
    @inlinable
    package init(_base: consuming Base) {
        self._base = _base
    }
}

extension SeqProtocol where Self: ~Copyable & ~Escapable {
    /// The shape that almost certainly cannot compile.
    @inlinable
    public var v2_map: V2_BuilderOwned<Self> {
        _read {
            // To yield a V2_BuilderOwned<Self> that holds owned Base,
            // we must construct one. The constructor consumes Base —
            // but `_read` only borrows self. Cannot move self.
            //
            // Uncommenting the body should fail at the declaration site:
            //
            // yield V2_BuilderOwned(_base: self)  // FAIL: cannot consume borrowed self
            //
            // Keep the body inert so V3+ stays buildable.
            fatalError("V2 disabled — declaration-level failure expected if body is enabled")
        }
    }
}
