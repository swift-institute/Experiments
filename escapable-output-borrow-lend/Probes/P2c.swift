// P2c — stored ~Escapable property lent via a `_read` coroutine accessor.

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
        _read {
            yield _out
        }
    }
}
