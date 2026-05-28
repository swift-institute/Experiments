// MARK: - AConformerLib: the GENERIC institute-bridge conformer, in a SEPARATE module.
//
// Mirrors the production module split: the conformance (Buffer.Linear.Inline: Sequenceable)
// lives in swift-buffer-linear-primitives, while .collect() is driven from a different
// module. Here `Region<Element>` + its Sequenceable conformance live in this library;
// A-xmodule-exe imports it and drives .collect() across the module boundary. This exercises
// the cross-module associated-type-witness resolution (swift_getAssociatedTypeWitnessSlowImpl)
// that the single-module target A did not reach.

public import Memory_Contiguous_Primitives
public import Memory_Cursor_Primitives
public import Sequence_Protocol_Primitives

/// A minimal GENERIC contiguous conformer, public so a separate executable module can
/// instantiate and drive it. ~Copyable to match the production conformer's ownership.
public struct Region<Element: Copyable & Escapable>: ~Copyable {
    public var storage: [Element]
    public init(_ storage: [Element]) { self.storage = storage }
}

extension Region: Memory.Contiguous.`Protocol` {
    public var span: Span<Element> { storage.span }

    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let s = span
        return try unsafe s.withUnsafeBufferPointer { (bp: UnsafeBufferPointer<Element>) throws(E) -> R in
            try body(bp)
        }
    }
}

// Sequenceable conformance ONLY (single conformance; NO Iterable, NO @_implements — the
// decisive control shape). Iterator witness = the GENERIC Memory.Cursor<Region<Element>>.
// makeIterator body is identical to the bridge default (Memory.Cursor(self)).
extension Region: Sequenceable where Element: Copyable & Escapable {
    public typealias Iterator = Memory.Cursor<Region<Element>>
    @inlinable
    public consuming func makeIterator() -> Memory.Cursor<Region<Element>> {
        Memory.Cursor(self)
    }
}
