// MARK: - AConformerLib: conformer relying PURELY on the bridge-default makeIterator().
//
// In ALL other targets the conformer supplies an EXPLICIT makeIterator() (because associated-
// type inference from the cross-module bridge default failed). But the CRASHING production shape
// (Buffer.Linear.Inline) declared ONLY @_implements typealiases and relied on the bridge's
// protocol-extension default `makeIterator() -> Memory.Cursor<Self>` (in the THIRD module,
// swift-memory-sequence-primitives) as the witness. A witness that is a protocol-extension
// default in a third module produces a witness thunk spanning three modules — a plausible
// demangle trigger the explicit-makeIterator targets bypass.
//
// This conformer pins Iterator via typealias but provides NO explicit makeIterator — forcing the
// witness to be the bridge default. If THIS crashes where the explicit-makeIterator variants did
// not, the trigger is the cross-module-default witness thunk.

public import Memory_Contiguous_Primitives
public import Memory_Cursor_Primitives
public import Memory_Sequence_Primitives  // the bridge — supplies the default makeIterator()
public import Sequence_Protocol_Primitives

/// A minimal GENERIC contiguous conformer that opts into Sequenceable and pins its Iterator,
/// but RELIES ON THE BRIDGE DEFAULT makeIterator() (no explicit one here).
public struct RegionBD<Element: Copyable & Escapable>: ~Copyable {
    public var storage: [Element]
    public init(_ storage: [Element]) { self.storage = storage }
}

extension RegionBD: Memory.Contiguous.`Protocol` {
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

// Pin Iterator; NO explicit makeIterator — the bridge default (cross-module, in
// swift-memory-sequence-primitives) is the witness.
extension RegionBD: Sequenceable where Element: Copyable & Escapable {
    public typealias Iterator = Memory.Cursor<RegionBD<Element>>
}
