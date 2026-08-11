// VectorProtocol.swift — Simulates Affine.Discrete.Vector.Protocol

public protocol VectorProtocol {
    var vector: Vector { get }
    init(_ vector: Vector)
}

extension Vector: VectorProtocol {
    @inlinable
    public var vector: Vector { self }

    /// Identity conformance (self-conformance).
    @inlinable
    public init(_ vector: Vector) {
        self = vector
    }
}
