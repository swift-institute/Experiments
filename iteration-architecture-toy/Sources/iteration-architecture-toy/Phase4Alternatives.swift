// MARK: - Phase 4 — Alternative shapes (Phase-2 makeIterator-via-Backing was REFUTED)
// (b) makeIterator directly over self.span — already CONFIRMED in Route1Direct.swift.
// Here: (a) closure-callback `withBacking`, and (c) witness-struct delegation.

// MARK: (a) Closure-callback — lend the backing for the duration of a call (no escaping value)
// Hypothesis: like forEach, a with-style closure accessor sidesteps the lifetime-return wall.
public extension MyFamily.`Protocol` where Self: ~Copyable & ~Escapable {
    borrowing func withBacking<R>(_ body: (borrowing Backing) -> R) -> R {
        body(backing)
    }
}

// MARK: (c) Witness-struct delegation — a value-of-closures carrying the borrowing forEach.
// Hypothesis: a struct holding a closure with a (borrowing ~Copyable Element) parameter and a
// (borrowing ~Escapable Source) parameter expresses the iteration as data, not a protocol default.
public struct BorrowForEachWitness<Source: ~Copyable & ~Escapable, Element: ~Copyable> {
    public let forEach: (borrowing Source, (borrowing Element) -> Void) -> Void
    @inlinable
    public init(forEach: @escaping (borrowing Source, (borrowing Element) -> Void) -> Void) {
        self.forEach = forEach
    }
}
