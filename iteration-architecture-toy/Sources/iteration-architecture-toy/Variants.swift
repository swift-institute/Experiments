// MARK: - Phase 3 — Concrete variants exercising the routes at RUNTIME
// Two element kinds: Copyable (routes 1 & 2 via direct-projection makeIterator) and
// ~Copyable (route 3 via the family forEach delegation — must compile AND run).

// MARK: Copyable variant — route 1 (Iterable, multipass copy over span)
public struct ToySet: ~Copyable {
    @usableFromInline var storage: [Int]
    @inlinable public init(_ storage: [Int]) { self.storage = storage }
}

extension ToySet: Memory.Contiguous {
    public typealias Element = Int
    public var span: Span<Int> {
        @_lifetime(borrow self) get { storage.span }
    }
}

extension ToySet: Collection.`Protocol` {
    public typealias Index = Int
    public var startIndex: Int { 0 }
    public var endIndex: Int { storage.count }
    public borrowing func index(after i: Int) -> Int { i &+ 1 }
    public subscript(position: Int) -> Int { storage[position] }
}

extension ToySet: Iterable {
    public typealias Iterator = iteration_architecture_toy.Iterator.Chunk<Int>
    // makeIterator() provided by the Route1Direct family default (over self.span).
}
