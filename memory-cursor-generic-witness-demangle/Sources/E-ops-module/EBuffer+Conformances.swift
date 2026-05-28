// MARK: - E-ops-module: the OPS module (mirrors "Buffer Linear Inline Primitives", plural).
//
// This module declares the `Memory.Contiguous.Protocol` + `Sequenceable` conformances for the
// type that lives in E-type-module — exactly as `Buffer Linear Inline Primitives` (plural)
// declares them for `Buffer.Linear.Inline` (whose type lives in `Buffer Linear Inline Primitive`,
// singular). This is the type/ops module SPLIT the prior reconstruction (target D) collapsed.
//
// The crashing production shape:
//   • DUAL `Iterable, Sequenceable` with an `@_implements` split (Iterable → Iterator.Chunk;
//     Sequenceable → Memory.Cursor<Self>).
//   • Relied on the protocol-extension-default `makeIterator()` from the THIRD module
//     (swift-memory-sequence-primitives) as the Sequenceable witness (no explicit makeIterator).
//
// This module reproduces both: it pins the Sequenceable Iterator to Memory.Cursor<Self> via
// @_implements but provides NO explicit Sequenceable makeIterator — forcing the cross-module
// (3-module-spanning) bridge-default witness thunk that is the leading demangle-trigger
// hypothesis (EXPERIMENT.md lines 80-87).

public import E_type_module
public import Storage_Inline_Primitives
public import Memory_Contiguous_Primitives
public import Memory_Cursor_Primitives
public import Memory_Sequence_Primitives   // the bridge — supplies the default makeIterator()
public import Memory_Iterator_Primitives   // the Iterable bridge — supplies Iterator.Chunk
public import Sequence_Protocol_Primitives
public import Iterable
public import Iterator_Primitive
public import Iterator_Chunk_Primitives

// (1) Memory.Contiguous.Protocol conformance is declared HERE (ops module, plural analog), but
//     the `span` witness is supplied by a member in the TYPE module (E-type-module) — matching
//     buffer-linear's split (conformance in `…Primitives` plural; `span` in `…Primitive` singular
//     via +Span.swift). Only `withUnsafeBufferPointer` is witnessed here.
extension EBuffer.Linear.Inline: Memory.Contiguous.`Protocol` {
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let s = span
        return try unsafe s.withUnsafeBufferPointer { (bp: UnsafeBufferPointer<Element>) throws(E) -> R in
            try body(bp)
        }
    }
}

// (2) DUAL Iterable + Sequenceable with @_implements split, relying on the cross-module
//     bridge-DEFAULT makeIterator() for Sequenceable (no explicit one). This mirrors the
//     EXACT crashing production form of Buffer.Linear.Inline.
extension EBuffer.Linear.Inline: Iterable, Sequenceable where Element: Copyable & Escapable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Chunk<Element>

    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Memory.Cursor<EBuffer<Element>.Linear.Inline<capacity>>

    // Iterable's makeIterator (borrowing) — explicit (the Iterable bridge default would also
    // serve, but the production conformer's Iterable side resolves through Iterator.Chunk).
    @inlinable
    @_lifetime(borrow self)
    public borrowing func makeIterator() -> Iterator_Primitive.Iterator.Chunk<Element> {
        Iterator_Primitive.Iterator.Chunk(span)
    }

    // NO explicit Sequenceable makeIterator() — the witness is the bridge default
    // `makeIterator() -> Memory.Cursor<Self>` in swift-memory-sequence-primitives (3rd module).
}
