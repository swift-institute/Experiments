// String.swift — Generic string type as Tagged<Tag, StringStorage>
//
// The typealias makes StringLib.String<Tag> a generic type.
// Bare `String` (zero type parameters) should resolve to Swift.String,
// while `String<SomeTag>` resolves to Tagged<SomeTag, StringStorage>.

@_exported import TaggedLib

public typealias String<Tag: ~Copyable> = Tagged<Tag, StringStorage>

// MARK: - Convenience Init

extension Tagged where RawValue == StringStorage, Tag: ~Copyable {
    /// Creates a string by adopting ownership of a null-terminated buffer.
    @inlinable
    public init(adopting pointer: UnsafeMutablePointer<Char>, count: Int) {
        self.init(__unchecked: (), StringStorage(adopting: pointer, count: count))
    }
}

// MARK: - Forwarding Properties

extension Tagged where RawValue == StringStorage, Tag: ~Copyable {
    /// The number of characters (excluding null terminator).
    @inlinable
    public var count: Int { _storage.count }
}
