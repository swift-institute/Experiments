// MARK: - Phase 2 — Route 2 (Sequenceable / consuming drain) family defaults
// The consuming drain iterator OWNS the consumed base and re-derives its span each next()
// (the real Memory.Cursor shape, doc §1 lines 204-209). Base must be OWNED (Escapable) to be
// consumed — so the single borrowed-view `Backing` of routes 1/3 cannot serve route 2.

public extension Iterator {
    @frozen
    struct Drain<Base: Memory.Contiguous & ~Copyable>: ~Copyable
        where Base.Element: Copyable {
        @usableFromInline var base: Base
        @usableFromInline var position: Int
        @inlinable
        public init(_ base: consuming Base) {
            self.base = base
            self.position = 0
        }
    }
}

extension Iterator.Drain: Iterator.`Protocol` where Base: ~Copyable {
    @inlinable
    public mutating func next() -> Base.Element? {
        let span = base.span                 // re-derive inside next(); never store ~Escapable span
        guard position < span.count else { return nil }
        defer { position &+= 1 }
        return span[position]
    }
}

// Route-2 family default: consuming makeIterator owning the consumed Self. No @_lifetime — the
// drain is Escapable (owns everything); an Escapable witness satisfies Sequenceable's
// @_lifetime(copy self) requirement without the annotation (bridge spike OQ-2 V2a).
public extension Memory.Contiguous
    where Self: ~Copyable, Self: Sequenceable, Element: Copyable,
          Self.Iterator == iteration_architecture_toy.Iterator.Drain<Self> {
    consuming func makeIterator() -> iteration_architecture_toy.Iterator.Drain<Self> {
        iteration_architecture_toy.Iterator.Drain(self)
    }
}
