// MARK: - D-lib: a @_rawLayout-backed contiguous conformer -> Sequenceable (wraps Storage.Inline).
//
// The plain-array Region conformers (targets A) did NOT crash (single-module, cross-module,
// debug, release). The one structural factor they lack vs the crashing Buffer.Linear.Inline<8>
// is @_rawLayout storage: Buffer.Linear.Inline is backed by Storage<Element>.Inline<capacity>,
// which is `@_rawLayout(likeArrayOf: Element, count: capacity)`. This target isolates that
// factor by OWNING a real Storage.Inline (the actual @_rawLayout primitive) and conforming the
// WRAPPER to Sequenceable — single conformance (NO Iterable, NO @_implements; the decisive
// control shape). Iterator witness = the GENERIC Memory.Cursor<Self>. No buffer-linear (avoids
// the parallel migration's Iterable-collision contamination, which produced a separate
// COMPILE-time witness-thunk error — an artifact of the in-flight migration, not the runtime
// crash under investigation).

public import Storage_Inline_Primitives
public import Storage_Primitive
public import Memory_Contiguous_Primitives
public import Memory_Cursor_Primitives
public import Sequence_Protocol_Primitives
public import Sequence_Hint_Primitives
public import Iterable
public import Iterator_Primitive
public import Iterator_Chunk_Primitives
import Index_Primitives
import Ordinal_Primitives
import Cardinal_Primitives
import Finite_Primitives_Core

/// A @_rawLayout-backed fixed-capacity contiguous conformer that OWNS a real
/// `Storage<Element>.Inline<capacity>` — the same @_rawLayout primitive backing
/// Buffer.Linear.Inline. Value-generic over `capacity`, matching Inline<let capacity:Int>.
public struct RawRegion<Element: Copyable & Escapable, let capacity: Int>: ~Copyable {
    @usableFromInline
    var storage: Storage<Element>.Inline<capacity>

    // Fills exactly `capacity` elements (repeating `values` cyclically if shorter) so the
    // full @_rawLayout storage span is initialized and can be returned directly — avoids
    // internal Span/_overrideLifetime plumbing. The crash is about the Iterator
    // associated-type WITNESS, not element count, so a full span is faithful.
    public init(fill value: Element) {
        var s = Storage<Element>.Inline<capacity>()
        for i in 0..<capacity {
            let slot = Index<Element>.Bounded<capacity>(Index<Element>(Ordinal(UInt(i))))!
            unsafe s.pointer(at: slot).initialize(to: value)
        }
        // Mark all `capacity` slots initialized so `storage.span` (which reads
        // `initialization.count`) reports the full span — otherwise the span is empty and the
        // cursor yields nothing (a data-population artifact, not a witness issue).
        s.initialization = .linear(count: Index<Element>.Count(Cardinal(UInt(capacity))))
        self.storage = s
    }
}

extension RawRegion: Memory.Contiguous.`Protocol` {
    // Delegate span + unsafe-buffer straight to the owned @_rawLayout Storage.Inline.
    @inlinable
    public var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get { storage.span }
    }

    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        // Reconstruct from the span (Storage.Inline.withUnsafeBufferPointer is untyped-rethrows
        // and doesn't compose with typed throws(E)).
        let s = span
        return try unsafe s.withUnsafeBufferPointer { (bp: UnsafeBufferPointer<Element>) throws(E) -> R in
            try body(bp)
        }
    }
}

// DUAL Iterable + Sequenceable with @_implements — the HIGHEST-FIDELITY reconstruction of the
// crashing Buffer.Linear.Inline shape: @_rawLayout storage + value-generic capacity + dual
// conformance + @_implements split + (driven cross-module). This is the single closest
// approximation to the verified crash that can be built without buffer-linear.
extension RawRegion: Iterable, Sequenceable where Element: Copyable & Escapable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Chunk<Element>

    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Memory.Cursor<RawRegion<Element, capacity>>

    @inlinable
    @_lifetime(borrow self)
    public borrowing func makeIterator() -> Iterator_Primitive.Iterator.Chunk<Element> {
        Iterator_Primitive.Iterator.Chunk(span)
    }

    @inlinable
    public consuming func makeIterator() -> Memory.Cursor<RawRegion<Element, capacity>> {
        Memory.Cursor(self)
    }
}

/// Drive `.collect()` on the @_rawLayout conformer from WITHIN this module, generic over
/// the value-generic capacity.
public func collectRaw<let capacity: Int>(
    fill value: Int, as _: RawRegion<Int, capacity>.Type
) -> [Int] {
    let region = RawRegion<Int, capacity>(fill: value)
    return region.collect()
}
