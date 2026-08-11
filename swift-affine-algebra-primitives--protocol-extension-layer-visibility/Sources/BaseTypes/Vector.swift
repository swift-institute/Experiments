// Vector.swift — Simulates Affine.Discrete.Vector (affine layer)

public struct Vector: Hashable, Sendable {
    public let rawValue: Int

    @inlinable
    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Additive identity — always present at the affine layer.
    @inlinable
    public static var zero: Self { Self(0) }

    // NOTE: .one is intentionally ABSENT here.
    // It will be provided via protocol extension in AlgebraExtension.
}
