// Vector+DirectOne.swift — Adds .one as a DIRECT member on Vector (simulates current production state)

public import BaseTypes

extension Vector {
    /// .one as a direct member — this is the current production state that causes the hazard.
    @inlinable
    public static var one: Self { Self(Vector(1)) }
}
