// MARK: - Phase 7 (Gap c) — CROSS-MODULE library target: iteration primitives
// This is the SECOND target in the package ([EXP-017]). It houses the base iteration protocols,
// the copy-self IterableByCopy capability, the FamD family protocol + D1 default, the route-3
// forEach family, and a route-2 Sequenceable family — all `public`. The executable target imports
// this module and exercises D1 / forEach (C) / route-2 ACROSS THE MODULE BOUNDARY, debug + release.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), arm64-apple-macosx26.0
// Result: CONFIRMED — this lib's family defaults (D1 makeIteratorD1, MyFamily forEach/C, route-2
//   drain) are inherited by DOWNSTREAM conformers in the executable target, debug + release,
//   warning-clean. See Phase7CrossModule.swift (executable) for the cross-module conformers and
//   main.swift's gap-(c) run block for the runtime evidence.

// MARK: Base single-pass cursor (yields OWNED elements; no @_lifetime on next()).
public enum Iterator {}

public extension Iterator {
    protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        mutating func next() -> Element?
    }
}

// MARK: A bulk iterator borrowing a Span (mirrors Iterator.Chunk in the executable module).
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

// MARK: Iterator.Drain — owning consuming-drain iterator for route 2 (re-derives span each next()).
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
        let span = base.span
        guard position < span.count else { return nil }
        defer { position &+= 1 }
        return span[position]
    }
}

// MARK: IterableByCopy — the copy-self makeIterator capability (D1's view protocol).
public protocol IterableByCopy: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: ~Copyable & ~Escapable
        where Iterator: iteration_architecture_toy_lib.Iterator.`Protocol`, Iterator.Element == Element
    @_lifetime(copy self)
    borrowing func makeIterator() -> Iterator
}

// MARK: Route-3 capability — a borrowing forEach (internal iteration).
public protocol BorrowForEachable: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    borrowing func forEach(_ body: (borrowing Element) -> Void)
}

// MARK: Sequenceable — consuming/drain makeIterator (route 2).
public protocol Sequenceable: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: ~Copyable & ~Escapable
        where Iterator: iteration_architecture_toy_lib.Iterator.`Protocol`, Iterator.Element == Element
    @_lifetime(copy self)
    consuming func makeIterator() -> Iterator
}

// MARK: Memory.Contiguous substrate (needed by Iterator.Drain / route 2).
public enum Memory {}

public extension Memory {
    protocol Contiguous: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        var span: Span<Element> { @_lifetime(borrow self) get }
    }
}
