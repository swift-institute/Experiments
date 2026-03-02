// Tagged.swift — Minimal reproduction of Identity_Primitives.Tagged
// Mirrors swift-identity-primitives exactly for cross-module fidelity.

public struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    @usableFromInline
    package var _storage: RawValue

    @inlinable
    public var rawValue: RawValue {
        _read { yield _storage }
        _modify { yield &_storage }
    }

    @inlinable
    public init(__unchecked: Void, _ rawValue: consuming RawValue) {
        self._storage = rawValue
    }

    @inlinable
    package mutating func modify<T>(_ body: (_ rawValue: inout RawValue) -> T) -> T {
        body(&_storage)
    }
}

// MARK: - Conditional Copyable

extension Tagged: Copyable where Tag: ~Copyable, RawValue: Copyable {}

// MARK: - Conditional Conformances

extension Tagged: Sendable where Tag: ~Copyable, RawValue: ~Copyable & Sendable {}
extension Tagged: BitwiseCopyable where Tag: ~Copyable, RawValue: BitwiseCopyable {}
extension Tagged: Equatable where Tag: ~Copyable, RawValue: Equatable {}
extension Tagged: Hashable where Tag: ~Copyable, RawValue: Hashable {}
extension Tagged: Comparable where Tag: ~Copyable, RawValue: Comparable {
    @inlinable
    public static func < (lhs: Tagged, rhs: Tagged) -> Bool {
        lhs._storage < rhs._storage
    }
}

// MARK: - Closure-Based Storage Access (Fallback for @_lifetime)

extension Tagged where Tag: ~Copyable, RawValue: ~Copyable {
    @inlinable
    public borrowing func withRawValue<R: ~Copyable, E: Swift.Error>(
        _ body: (borrowing RawValue) throws(E) -> R
    ) throws(E) -> R {
        try body(_storage)
    }
}

// MARK: - Functor (Static)

extension Tagged where Tag: ~Copyable, RawValue: ~Copyable {
    @inlinable
    public static func map<E: Error, NewRawValue: ~Copyable>(
        _ tagged: consuming Tagged,
        transform: (consuming RawValue) throws(E) -> NewRawValue
    ) throws(E) -> Tagged<Tag, NewRawValue> {
        Tagged<Tag, NewRawValue>(__unchecked: (), try transform(tagged._storage))
    }

    @inlinable
    public static func retag<NewTag: ~Copyable>(
        _ tagged: consuming Tagged,
        to _: NewTag.Type = NewTag.self
    ) -> Tagged<NewTag, RawValue> {
        Tagged<NewTag, RawValue>(__unchecked: (), tagged._storage)
    }
}

// MARK: - Functor (Instance)

extension Tagged where Tag: ~Copyable, RawValue: ~Copyable {
    @inlinable
    public consuming func map<E: Error, NewRawValue: ~Copyable>(
        _ transform: (consuming RawValue) throws(E) -> NewRawValue
    ) throws(E) -> Tagged<Tag, NewRawValue> {
        try Self.map(self, transform: transform)
    }

    @inlinable
    public consuming func retag<NewTag: ~Copyable>(
        _: NewTag.Type = NewTag.self
    ) -> Tagged<NewTag, RawValue> {
        Self.retag(self, to: NewTag.self)
    }
}
