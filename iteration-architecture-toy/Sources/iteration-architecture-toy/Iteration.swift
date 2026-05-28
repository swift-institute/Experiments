// MARK: - Phase 1 — Toy iteration primitives (no deps)
// Faithful-but-minimal models of the institute's three-route iteration protocols.
// Shapes mirror the verified ground truth in
// swift-institute/Research/memory-contiguous-iteration-bridge.md §"Verified Ground Truth".

// MARK: Iterator.`Protocol` — the base single-pass cursor (yields OWNED elements)
// Real: Iterator.`Protocol` & ~Copyable & ~Escapable, @_lifetime(&self) next().

public enum Iterator {}

public extension Iterator {
    protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        // No @_lifetime: the base cursor yields OWNED (Escapable) elements, so the result
        // carries no lifetime dependence on self. (The borrow route below is where it bites.)
        mutating func next() -> Element?
    }
}

// MARK: Iterable — multipass / borrowing makeIterator (route 1, copy)
// Real: structurally Sequence.Borrowing.`Protocol` — @_lifetime(borrow self) borrowing
// makeIterator() -> Iterator (Iterator is ~Copyable & ~Escapable, borrows self).
// NOTE: the `Iterator` associated type shadows the `Iterator` namespace inside the body,
// so the base-protocol constraint must be module-qualified (`iteration_architecture_toy.`).

public protocol Iterable: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: ~Copyable & ~Escapable
        where Iterator: iteration_architecture_toy.Iterator.`Protocol`,
              Iterator.Element == Element
    @_lifetime(borrow self)
    borrowing func makeIterator() -> Iterator
}

// MARK: Sequenceable — consuming / drain makeIterator (route 2, consume)
// Real: Sequenceable<Element>: ~Copyable, ~Escapable — @_lifetime(copy self) consuming
// makeIterator() -> Iterator. The iterator OWNS / is lifetime-bound to the consumed source.

public protocol Sequenceable: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: ~Copyable & ~Escapable
        where Iterator: iteration_architecture_toy.Iterator.`Protocol`,
              Iterator.Element == Element
    @_lifetime(copy self)
    consuming func makeIterator() -> Iterator
}

// MARK: Ownership.Borrow<Wrapped> — a ~Escapable lend of a (possibly ~Copyable) element.
// Wrapped is ~Copyable but Escapable: a pointer/Span can only address Escapable storage
// (Span/UnsafePointer both force Escapable — verified Phase 1). Route 3's payload.

public enum Ownership {}

public extension Ownership {
    @frozen @safe
    struct Borrow<Wrapped: ~Copyable>: ~Copyable, ~Escapable {
        @usableFromInline let _address: UnsafePointer<Wrapped>
        @_lifetime(borrow value)
        @inlinable
        public init(_ value: borrowing Wrapped) {
            let pointer = unsafe withUnsafePointer(to: value) { unsafe $0 }
            unsafe self._address = pointer
        }
        @inlinable
        public var value: Wrapped {
            unsafeAddress { unsafe _address }
        }
    }
}

// MARK: Iterator.Borrow.`Protocol` — multipass BORROW cursor (route 3, ~Copyable elements)
// Lends Ownership.Borrow<Element> per step; @_lifetime(&self) because the result borrows self.

public extension Iterator {
    enum Borrow {}
}

public extension Iterator.Borrow {
    protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        @_lifetime(&self)
        mutating func next() -> Ownership.Borrow<Element>?
    }
}
