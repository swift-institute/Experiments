// MARK: - QLib — Sequence.Protocol stand-in module
// Splits the Q protocol into its own module to mirror the production layout
// where Sequence.Protocol lives in Sequence_Protocol module separate from
// the consumer's Sequence Hint module containing collect.swift.

public protocol Q<Element>: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: IteratorQProto & ~Copyable & ~Escapable
        where Iterator.Element == Element

    @_lifetime(copy self)
    consuming func makeIterator() -> Iterator
}

public protocol IteratorQProto<Element>: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    mutating func next() -> Element?
}

public struct IteratorQ<Element>: IteratorQProto {
    public var slot: UInt = 0
    public init() {}
    public mutating func next() -> Element? { return nil }
}

public struct EmptyQ<Element>: Q, ~Copyable {
    public typealias Iterator = IteratorQ<Element>
    public init() {}
    public consuming func makeIterator() -> IteratorQ<Element> { IteratorQ<Element>() }
}
