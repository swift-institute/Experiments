// P2a — stored ~Escapable property, NO pointer; lend a borrow tied to self
// via a plain return under @_lifetime(&self).
//
// Output is a genuinely ~Escapable view. The iterator stores it as a plain
// stored `var _out: Output` and lends it on each next().

struct Output: ~Escapable {
    let value: Int
    @_lifetime(immortal)
    init(_ value: Int) { self.value = value }
}

struct Iter: ~Copyable, ~Escapable {
    var _out: Output
    var index: Int

    // Explicit lifetime init: self's lifetime derives from the seeded output.
    @_lifetime(copy seed)
    init(seed: consuming Output) {
        self._out = seed
        self.index = 0
    }

    @_lifetime(&self)
    mutating func next() -> Output? {
        guard index < 3 else { return nil }
        _out = Output(index)   // mutate stored ~Escapable output
        index += 1
        return _out            // lend a borrow of stored output tied to self
    }
}
