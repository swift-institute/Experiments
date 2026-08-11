// Enumeration.swift
// Mimics Finite.Enumeration as Sequence-only (no Collection, no Index dependency).
//
// Collection conformance moves to the integration package where Index<Element>
// is available. This file only needs Ordinal (here simplified to Int).

/// A zero-allocation, lazy sequence over an `Enumerable` type.
public struct Enumeration<Element: Enumerable>: Sequence, Sendable {
    @inlinable
    public init() {}

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator()
    }

    /// Iterator that lazily produces each value in index order.
    public struct Iterator: IteratorProtocol, Sendable {
        @usableFromInline
        var index: Int = 0

        @inlinable
        init() {}

        @inlinable
        public mutating func next() -> Element? {
            guard index < Element.count else { return nil }
            defer { index += 1 }
            return Element(__unchecked: (), ordinal: index)
        }
    }
}

// MARK: - Total Element Access

extension Enumeration {
    /// Returns the element at the given position, or `nil` if out of bounds.
    @inlinable
    public func element(at position: Int) -> Element? {
        guard position >= 0, position < Element.count else { return nil }
        return Element(__unchecked: (), ordinal: position)
    }
}
