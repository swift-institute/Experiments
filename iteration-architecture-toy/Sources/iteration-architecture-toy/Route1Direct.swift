// MARK: - Phase 2 — Route 1 makeIterator DIRECT-projection default (no Backing indirection)
// Discriminator: does the lifetime wall sink EVERY family-level makeIterator default, or only
// the backing.makeIterator() DELEGATION (which borrows a local temporary)? Here makeIterator
// constructs the iterator over self.span directly, with a @_lifetime(copy span) init — the real
// memory→Iterable bridge shape. `copy` should flatten span's (borrow-self) dependency into the
// iterator, unlike `borrow`-of-a-local.

// A minimal bulk iterator borrowing a Span (mirrors Iterator.Chunk).
public extension Iterator {
    @frozen
    struct Chunk<Element>: ~Escapable {
        @usableFromInline var span: Span<Element>
        @usableFromInline var position: Int
        @_lifetime(copy span)
        @inlinable
        public init(_ span: consuming Span<Element>) {
            self.span = span
            self.position = 0
        }
    }
}

extension Iterator.Chunk: Iterator.`Protocol` {
    @inlinable
    public mutating func next() -> Element? {
        guard position < span.count else { return nil }
        defer { position &+= 1 }
        return span[position]
    }
}

// The direct makeIterator default, expressed on Memory.Contiguous itself (the substrate that
// IS the "family" for contiguous variants). This is the green production bridge shape.
public extension Memory.Contiguous
    where Self: ~Copyable & ~Escapable, Self: Iterable, Element: Copyable,
          Iterator == iteration_architecture_toy.Iterator.Chunk<Element> {
    @_lifetime(borrow self)
    borrowing func makeIterator() -> iteration_architecture_toy.Iterator.Chunk<Element> {
        iteration_architecture_toy.Iterator.Chunk(self.span)
    }
}
