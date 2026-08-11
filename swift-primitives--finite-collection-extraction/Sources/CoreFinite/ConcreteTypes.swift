// ConcreteTypes.swift
// Concrete types conforming to Enumerable — mimics comparison/ordering types.

/// Mimics Comparison.Bound (2 cases).
public struct Bound: Enumerable {
    public static let count = 2
    public let ordinal: Int
    public init(__unchecked: Void, ordinal: Int) { self.ordinal = ordinal }

    public static let lower = Bound(__unchecked: (), ordinal: 0)
    public static let upper = Bound(__unchecked: (), ordinal: 1)
}

/// Mimics Ordering.Ternary (3 cases).
public struct Ternary: Enumerable {
    public static let count = 3
    public let ordinal: Int
    public init(__unchecked: Void, ordinal: Int) { self.ordinal = ordinal }

    public static let ascending  = Ternary(__unchecked: (), ordinal: 0)
    public static let equivalent = Ternary(__unchecked: (), ordinal: 1)
    public static let descending = Ternary(__unchecked: (), ordinal: 2)
}
