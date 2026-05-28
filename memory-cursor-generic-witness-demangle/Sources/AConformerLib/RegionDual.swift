// MARK: - AConformerLib: the EXACT crashing production shape — DUAL Iterable + Sequenceable.
//
// This reconstructs the shape that was orchestrator-verified crashing on
// `Buffer.Linear.Inline<8>: Sequenceable` (a transient working-tree state in
// swift-buffer-linear-primitives, since migrated away by a parallel subordinate):
//
//   extension Buffer.Linear.Inline: Iterable, Sequenceable where Element: Copyable {
//       @_implements(Iterable, Iterator)     typealias IterableIterator     = Iterator.Chunk<Element>
//       @_implements(Sequenceable, Iterator) typealias SequenceableIterator = Memory.Cursor<Self>
//   }
//
// Both Iterable and Sequenceable declare `associatedtype Iterator`, which Swift UNIFIES;
// the dual conformer splits the two bindings with @_implements (the associated-type-trap
// escape hatch). The two witnesses are DIFFERENT generic structs over Self:
//   Iterable.Iterator      = Iterator.Chunk<Element>          (span-backed bulk iterator)
//   Sequenceable.Iterator  = Memory.Cursor<RegionDual<Element>> (owned cursor over Self)
//
// RegionDualGeneric (this file) reproduces that on a minimal GENERIC conformer.

public import Memory_Contiguous_Primitives
public import Memory_Cursor_Primitives
public import Memory_Sequence_Primitives
public import Sequence_Protocol_Primitives
public import Iterable
public import Iterator_Primitive
public import Iterator_Chunk_Primitives

/// A minimal GENERIC contiguous conformer declaring BOTH attachables, mirroring the
/// crashing `Buffer.Linear.Inline: Iterable, Sequenceable` dual conformance exactly.
public struct RegionDual<Element: Copyable & Escapable>: ~Copyable {
    public var storage: [Element]
    public init(_ storage: [Element]) { self.storage = storage }
}

extension RegionDual: Memory.Contiguous.`Protocol` {
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

// DUAL conformance with @_implements split — the EXACT crashing shape. Both bridges vend
// the iterators (no hand-written iterators): memory->Iterable vends Iterator.Chunk;
// memory->Sequenceable vends Memory.Cursor. The two Iterator associated-type witnesses are
// different generic structs over the conformer.
extension RegionDual: Iterable, Sequenceable where Element: Copyable & Escapable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Chunk<Element>

    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Memory.Cursor<RegionDual<Element>>

    // Iterable.makeIterator (borrowing) — vends the bulk Chunk over the span.
    @inlinable
    @_lifetime(borrow self)
    public borrowing func makeIterator() -> Iterator_Primitive.Iterator.Chunk<Element> {
        Iterator_Primitive.Iterator.Chunk(span)
    }

    // Sequenceable.makeIterator (consuming) — vends the owned Memory.Cursor over Self.
    // (Escapable result => @_lifetime omitted; the Escapable witness satisfies the
    //  @_lifetime(copy self) requirement.)
    @inlinable
    public consuming func makeIterator() -> Memory.Cursor<RegionDual<Element>> {
        Memory.Cursor(self)
    }
}
