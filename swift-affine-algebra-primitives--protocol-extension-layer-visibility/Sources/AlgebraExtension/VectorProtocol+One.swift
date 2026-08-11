// VectorProtocol+One.swift — Simulates algebra layer providing .one via protocol extension

public import BaseTypes

extension VectorProtocol {
    /// Multiplicative unit — only visible when AlgebraExtension is imported.
    @inlinable
    public static var one: Self { Self(Vector(1)) }
}
