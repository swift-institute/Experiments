// Ordinal.swift — Simulates Ordinal with two init overloads

public struct Ordinal: Hashable, Sendable {
    public let rawValue: UInt

    @inlinable
    public init(_ rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// Non-throwing init from Cardinal (always safe).
    @inlinable
    public init(_ cardinal: Cardinal) {
        self.init(cardinal.rawValue)
    }

    /// Throwing init from Vector (partial — negative vectors are invalid).
    @inlinable
    public init(_ vector: Vector) throws(OrdinalError) {
        guard vector.rawValue >= 0 else { throw .negativeSource }
        self.init(UInt(vector.rawValue))
    }
}

public enum OrdinalError: Error {
    case negativeSource
}
