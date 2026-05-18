// MARK: - V2: Multi-arity Cursor<Storage, PositionTag>
//
// Purpose: Test whether multi-arity generic discriminates W2's separate
// DomainTag (Byte/Text/...) from Storage. W1 and W3 derive PositionTag from
// Storage (PositionTag = Storage for W1, PositionTag = Element for W3).
// W2 has PositionTag = a separate phantom tag distinct from Storage = Span<UInt8>.
//
// Hypothesis: Multi-arity generic compiles; typealiases bind PositionTag
// per World shape; conditional Copyable/Escapable still lift correctly.
//
// Toolchain: Swift 6.3.1
// Result: TBD

public import Tagged_Primitives
public import Ordinal_Primitives
public import Cardinal_Primitives

public enum CursorV2 {}

extension CursorV2 {
    @safe
    public struct Cursor<
        Storage: ~Copyable & ~Escapable,
        PositionTag: ~Copyable & ~Escapable
    >: ~Copyable, ~Escapable {
        @usableFromInline
        internal var storage: Storage

        @usableFromInline
        internal var _position: Tagged<PositionTag, Ordinal>

        @inlinable
        @_lifetime(borrow storage)
        public init(_ storage: borrowing Storage) where Storage: Copyable {
            self.storage = copy storage
            self._position = Tagged<PositionTag, Ordinal>(_unchecked: Ordinal(UInt(0)))
        }
    }
}

extension CursorV2.Cursor: Copyable
where Storage: Copyable & ~Escapable, PositionTag: ~Copyable & ~Escapable {}

extension CursorV2.Cursor: Escapable
where Storage: Escapable & ~Copyable, PositionTag: ~Copyable & ~Escapable {}

// MARK: - World-specific typealiases
//
// W2: Span-backed, separate DomainTag for the byte/text domain
public enum ByteDomain {}
public enum TextDomain {}

extension CursorV2 {
    public typealias W2<DomainTag: ~Copyable & ~Escapable> =
        CursorV2.Cursor<Swift.Span<UInt8>, DomainTag>
}

// W3: Array-backed, Element-tagged
extension CursorV2 {
    public typealias W3<Element> = CursorV2.Cursor<[Element], Element>
}

// W1: Owned ~Copyable storage. To get distinct read-only vs read-write
// types here we'd need additional generics or a Mode parameter — deferred
// to V3.
