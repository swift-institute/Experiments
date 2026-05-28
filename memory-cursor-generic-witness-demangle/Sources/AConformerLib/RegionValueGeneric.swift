// MARK: - AConformerLib: a VALUE-GENERIC contiguous conformer (one factor closer to Inline).
//
// Buffer.Linear.Inline<let capacity: Int> is parameterized by a VALUE generic parameter
// (SE-0452 integer generic parameter), not just a type. Value generics participate in
// runtime type-metadata mangling differently from type generics — a candidate trigger for
// the `swift_getAssociatedTypeWitnessSlowImpl` demangle failure. This conformer adds ONLY
// that one factor over `Region<Element>` ([EXP-021] one-factor-at-a-time): a
// `<let capacity: Int>` value parameter, still backed by a plain array (no @_rawLayout —
// that backing lives in buffer-linear internals this experiment must not touch).

public import Memory_Contiguous_Primitives
public import Memory_Cursor_Primitives
public import Sequence_Protocol_Primitives

/// A GENERIC contiguous conformer with a VALUE generic parameter `capacity`, mirroring
/// `Buffer.Linear.Inline<let capacity: Int>`'s parameterization shape.
public struct RegionVG<Element: Copyable & Escapable, let capacity: Int>: ~Copyable {
    public var storage: [Element]
    public init(_ storage: [Element]) {
        precondition(storage.count <= capacity)
        self.storage = storage
    }
}

extension RegionVG: Memory.Contiguous.`Protocol` {
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

extension RegionVG: Sequenceable where Element: Copyable & Escapable {
    public typealias Iterator = Memory.Cursor<RegionVG<Element, capacity>>
    @inlinable
    public consuming func makeIterator() -> Memory.Cursor<RegionVG<Element, capacity>> {
        Memory.Cursor(self)
    }
}
