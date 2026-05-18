// MARK: - V5: ~Copyable Storage wrapper for W2
//
// V3/V4 refuted Mode-discriminator approaches. Conditional Copyable on
// suppressible protocols can only inherit from the parameter's own
// Copyable conformance — it cannot discriminate via auxiliary same-type
// or custom-protocol constraints.
//
// V5 tries a different angle: instead of using `Span<UInt8>` as Storage
// directly (which is Copyable and forces the cursor Copyable via
// inheritance), wrap Span in a `~Copyable` proxy. With Storage =
// ~Copyable, the conditional Copyable extension doesn't fire, and the
// cursor stays ~Copyable for W2.
//
// Hypothesis: Cursor<BorrowedBytes, DomainTag> is ~Copyable as desired
// because BorrowedBytes is ~Copyable. The Three-Worlds shape collapses
// into one generic at the cost of one ~Copyable wrapping layer for W2.
//
// Toolchain: Swift 6.3.1
// Result: TBD

public import Tagged_Primitives
public import Ordinal_Primitives

public enum CursorV5 {}

extension CursorV5 {
    /// ~Copyable wrapper around a borrowed Span<UInt8>. The ~Copyable
    /// attribute propagates to any cursor over BorrowedBytes, giving W2
    /// affine ownership without needing a Mode discriminator.
    @safe
    public struct BorrowedBytes: ~Copyable, ~Escapable {
        @usableFromInline
        internal let span: Swift.Span<UInt8>

        @inlinable
        @_lifetime(borrow span)
        public init(_ span: borrowing Swift.Span<UInt8>) {
            self.span = copy span
        }
    }
}

extension CursorV5 {
    @safe
    public struct Cursor<
        Storage: ~Copyable & ~Escapable,
        PositionTag: ~Copyable & ~Escapable
    >: ~Copyable, ~Escapable {
        @usableFromInline
        internal var storage: Storage

        @usableFromInline
        internal var _position: Tagged<PositionTag, Ordinal>

        // Copyable-Storage init: borrow-then-copy.
        @inlinable
        @_lifetime(borrow storage)
        public init(_ storage: borrowing Storage) where Storage: Copyable {
            self.storage = copy storage
            self._position = Tagged<PositionTag, Ordinal>(_unchecked: Ordinal(UInt(0)))
        }

        // ~Copyable-Storage init: consume.
        @inlinable
        @_lifetime(copy storage)
        public init(consumingStorage storage: consuming Storage) {
            self.storage = storage
            self._position = Tagged<PositionTag, Ordinal>(_unchecked: Ordinal(UInt(0)))
        }
    }
}

extension CursorV5.Cursor: Copyable
where Storage: Copyable & ~Escapable, PositionTag: ~Copyable & ~Escapable {}

extension CursorV5.Cursor: Escapable
where Storage: Escapable & ~Copyable, PositionTag: ~Copyable & ~Escapable {}

// MARK: - World typealiases

public enum ByteDomainV5 {}
public enum TextDomainV5 {}

extension CursorV5 {
    /// W2 — borrowed Span-cursor. Storage = BorrowedBytes (~Copyable wrapper)
    /// → Cursor stays ~Copyable. DomainTag is the phantom position tag.
    public typealias W2<DomainTag: ~Copyable & ~Escapable> =
        CursorV5.Cursor<CursorV5.BorrowedBytes, DomainTag>

    /// W3 — owned Copyable input. Storage = [Element].
    public typealias W3<Element> =
        CursorV5.Cursor<[Element], Element>
}
