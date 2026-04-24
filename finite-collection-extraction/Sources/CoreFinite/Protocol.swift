// Protocol.swift
// Mimics Finite.Enumerable WITHOUT CaseIterable.
//
// CaseIterable is an integration concern (requires Collection, which requires
// Index<Element>). It belongs in the integration package.

/// A finite type with indexed, enumerable values.
///
/// Mirrors `Finite.Enumerable` — pure finite domain, no collection dependency.
public protocol Enumerable: Sendable {
    /// Number of distinct values.
    static var count: Int { get }

    /// Ordinal position of this value (0 to count-1).
    var ordinal: Int { get }

    /// Creates a value from its ordinal without bounds checking.
    init(__unchecked: Void, ordinal: Int)
}

// MARK: - Total Initializer

extension Enumerable {
    /// Creates a value from its ordinal, if within bounds.
    @inlinable
    public init?(_ ordinal: Int) {
        guard ordinal >= 0, ordinal < Self.count else { return nil }
        self.init(__unchecked: (), ordinal: ordinal)
    }
}
