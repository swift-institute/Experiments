// MARK: - Tagged (production-faithful: _read coroutine on rawValue)

public struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    @usableFromInline
    internal var _storage: RawValue

    @inlinable
    public var rawValue: RawValue {
        _read { yield _storage }
        _modify { yield &_storage }
    }

    @inlinable
    public init(_ rawValue: consuming RawValue) {
        self._storage = rawValue
    }
}

extension Tagged: Copyable where Tag: ~Copyable, RawValue: Copyable {}
extension Tagged: Sendable where Tag: ~Copyable, RawValue: ~Copyable & Sendable {}

// MARK: - TaggedStored (public stored property, no _storage indirection)

public struct TaggedStored<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    public var rawValue: RawValue

    @inlinable
    public init(_ rawValue: consuming RawValue) {
        self.rawValue = rawValue
    }
}

extension TaggedStored: Copyable where Tag: ~Copyable, RawValue: Copyable {}
extension TaggedStored: Sendable where Tag: ~Copyable, RawValue: ~Copyable & Sendable {}
