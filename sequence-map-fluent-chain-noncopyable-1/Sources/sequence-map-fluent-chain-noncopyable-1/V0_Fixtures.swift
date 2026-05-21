// Minimal Sequence.Protocol-shaped fixtures for the experiment.
//
// We avoid depending on swift-sequence-primitives so the experiment is
// self-contained and reflects the language-level constraint, not the
// ecosystem state.

public protocol SeqProtocol<Element>: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    associatedtype Iter: ~Copyable & ~Escapable

    @_lifetime(copy self)
    consuming func makeIterator() -> Iter
}

/// Minimal Sequence.Iterator.Protocol-shaped fixture.
public protocol IterProtocol<Element>: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    mutating func next() -> Element?
}

// MARK: - ~Copyable conformer used to exercise the call-site shapes

/// `~Copyable & ~Escapable` source used to exercise the move-checker.
public struct NCSource: SeqProtocol, ~Copyable {
    public typealias Element = Int

    @usableFromInline
    var _elements: [Int]

    @inlinable
    public init(_ elements: [Int]) {
        self._elements = elements
    }

    @_lifetime(copy self)
    @inlinable
    public consuming func makeIterator() -> Iter {
        Iter(_elements: _elements)
    }

    public struct Iter: IterProtocol, ~Copyable {
        public typealias Element = Int

        @usableFromInline
        var _elements: [Int]

        @usableFromInline
        var _index: Int = 0

        @inlinable
        init(_elements: [Int]) {
            self._elements = _elements
        }

        @inlinable
        public mutating func next() -> Int? {
            guard _index < _elements.count else { return nil }
            defer { _index += 1 }
            return _elements[_index]
        }
    }
}
