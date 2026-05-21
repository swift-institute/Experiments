// V1 — Reproduce the parent's baseline failure: `consuming get` on a
// protocol extension where Self: ~Copyable & ~Escapable, called from
// a direct user call site on a let-bound source.
//
// Expected verdict per parser-primitives EXPERIMENT.md and
// `swift-institute/Research/2026-05-18-consuming-get-protocol-extension-noncopyable-limitation.md`:
// FAIL with `sil_movechecking_capture_consumed`-class diagnostic
// ("'self' is borrowed and cannot be consumed" or "noncopyable 'X'
// cannot be consumed when captured by an escaping closure or borrowed
// by a non-Escapable type").

/// V1 Builder — owns base via consuming init.
public struct V1_Builder<Base: SeqProtocol & ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    @usableFromInline
    var _base: Base

    @_lifetime(copy _base)
    @inlinable
    package init(_base: consuming Base) {
        self._base = _base
    }
}

extension SeqProtocol where Self: ~Copyable & ~Escapable {
    /// The failing-direction accessor we want to ship.
    @inlinable
    public var v1_map: V1_Builder<Self> {
        consuming get { V1_Builder(_base: self) }
    }
}

// Direct user call site — the entire point of the investigation.
@inlinable
public func runV1Direct() {
    let source = NCSource([1, 2, 3])
    // Toggle the body to verify the diagnostic; commented to keep the
    // baseline experiment compiling so V2+ can be tested in the same
    // package.
    // let _ = source.v1_map      // EXPECT FAIL
    _ = source                    // suppress unused warning
}
