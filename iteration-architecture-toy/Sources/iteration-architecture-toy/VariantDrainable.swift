// MARK: - Phase 3 — Copyable variant exercising route 2 (Sequenceable / consuming drain)
// Uses the Route2 family default (generic owning-drain over consumed Self). The bridge spike
// (memory-contiguous-iteration-bridge.md OQ-2) found the GENERIC owning-cursor Sequenceable
// bridge crashes at runtime for generic conformers (swift_getAssociatedTypeWitness demangle).
// This variant exercises the toy's generic path to see whether it reproduces that crash.

public struct ToyDrainable: ~Copyable {
    @usableFromInline var storage: [Int]
    @inlinable public init(_ storage: [Int]) { self.storage = storage }
}

extension ToyDrainable: Memory.Contiguous {
    public typealias Element = Int
    public var span: Span<Int> {
        @_lifetime(borrow self) get { storage.span }
    }
}

extension ToyDrainable: Collection.`Protocol` {
    public typealias Index = Int
    public var startIndex: Int { 0 }
    public var endIndex: Int { storage.count }
    public borrowing func index(after i: Int) -> Int { i &+ 1 }
    public subscript(position: Int) -> Int { storage[position] }
}

extension ToyDrainable: Sequenceable {
    public typealias Iterator = iteration_architecture_toy.Iterator.Drain<ToyDrainable>
    // makeIterator() consuming provided by the Route2 family default.
}
