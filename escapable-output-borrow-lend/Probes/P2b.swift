// P2b — stored ~Escapable property lent via a `borrow` accessor
// (SE-0507, -enable-experimental-feature BorrowAndMutateAccessors).
// Production-gated: rejected on 6.3.2.
//
// Compile with: -enable-experimental-feature BorrowAndMutateAccessors

struct Output: ~Escapable {
    let value: Int
    @_lifetime(immortal)
    init(_ value: Int) { self.value = value }
}

struct Iter: ~Copyable, ~Escapable {
    var _out: Output

    @_lifetime(copy seed)
    init(seed: consuming Output) { self._out = seed }

    var current: Output {
        @_lifetime(borrow self)
        borrow {
            _out
        }
    }
}
