// Index.swift
// Mimics Index<Element> from index-primitives — phantom-typed wrapper around Int.

/// A phantom-typed index for type-safe collection access.
public struct Index<Element>: Comparable, Hashable, Sendable {
    public let position: Int

    @inlinable
    public init(_ position: Int) {
        self.position = position
    }

    @inlinable
    public static func < (lhs: Index, rhs: Index) -> Bool {
        lhs.position < rhs.position
    }
}
