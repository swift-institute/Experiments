// MARK: - BorrowLendKit
//
// Cross-module home ([EXP-017]) for the achievable-TODAY shapes that lend a
// genuinely ~Escapable output from an iterator, tied to self. Consumed across
// the module boundary by the executable target.
//
// Result: see top-level header. Both shapes compile + run on Apple Swift 6.3.2
// (debug AND release), cross-module — TODAY, no experimental stdlib.

// MARK: - P2a shape: stored ~Escapable output, plain return under @_lifetime(&self)

/// A genuinely ~Escapable output view (no Escapable conformance).
public struct OutputP2a: ~Escapable {
    public let value: Int
    @_lifetime(immortal)
    public init(_ value: Int) { self.value = value }
}

/// Iterator that stores a ~Escapable output as a PLAIN stored property (no
/// pointer) and lends it on each next(), lifetime-tied to self.
public struct IterP2a: ~Copyable, ~Escapable {
    var _out: OutputP2a
    var index: Int

    @_lifetime(immortal)
    public init() {
        self._out = OutputP2a(0)
        self.index = 0
    }

    @_lifetime(&self)
    public mutating func next() -> OutputP2a? {
        guard index < 3 else { return nil }
        _out = OutputP2a(index * 100)
        index += 1
        return _out
    }
}

// MARK: - P4 shape: bespoke nested ~Escapable Borrowed vending struct

/// The ~Escapable output view: a borrowed window over the iterator's slot.
public struct Borrowed: ~Escapable {
    let p: UnsafePointer<Int>
    @_lifetime(borrow owner)
    public init(_ p: UnsafePointer<Int>, borrowing owner: borrowing some ~Copyable & ~Escapable) {
        self.p = p
    }
    public var value: Int { unsafe p.pointee }
}

/// Iterator owning an Int slot; vends a ~Escapable Borrowed view tied to self.
public struct IterP4: ~Copyable, ~Escapable {
    let slot: UnsafeMutablePointer<Int>   // Int IS Escapable — slot is legal
    var index: Int

    @_lifetime(immortal)
    public init() {
        slot = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        slot.initialize(to: 0)
        index = 0
    }

    public consuming func finish() {
        slot.deinitialize(count: 1)
        slot.deallocate()
    }

    @_lifetime(&self)
    public mutating func next() -> Borrowed? {
        guard index < 3 else { return nil }
        slot.pointee = index * 10
        index += 1
        return Borrowed(UnsafePointer(slot), borrowing: self)
    }
}
