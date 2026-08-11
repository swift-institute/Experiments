// Cardinal.swift — Simulates Cardinal with .one

public struct Cardinal: Hashable, Sendable {
    public let rawValue: UInt

    @inlinable
    public init(_ rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// Semiring identity — always present.
    @inlinable
    public static var one: Self { Self(1) }
}
