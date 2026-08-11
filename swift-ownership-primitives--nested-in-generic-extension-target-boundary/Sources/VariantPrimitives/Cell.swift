public final class _Box<T: ~Copyable>: @unsafe @unchecked Sendable {
    @usableFromInline
    var _storage: UnsafeMutablePointer<T>?

    @usableFromInline
    init(_ value: consuming T) {
        let p = UnsafeMutablePointer<T>.allocate(capacity: 1)
        unsafe p.initialize(to: value)
        unsafe (_storage = p)
    }

    @usableFromInline
    func take() -> T {
        let p = unsafe _storage!
        unsafe (_storage = nil)
        let value = unsafe p.move()
        unsafe p.deallocate()
        return value
    }

    deinit {
        if let p = unsafe _storage {
            unsafe p.deinitialize(count: 1)
            unsafe p.deallocate()
        }
    }
}

extension Outer.Inner {
    public struct Cell<T: ~Copyable>: ~Copyable {
        @usableFromInline
        let _box: _Box<T>

        public init(_ value: consuming T) {
            _box = _Box(value)
        }

        public struct Token: Sendable {
            @usableFromInline
            let _box: _Box<T>

            @usableFromInline
            init(_ box: _Box<T>) {
                self._box = box
            }
        }
    }
}

extension Outer.Inner.Cell where T: ~Copyable {
    public consuming func token() -> Token {
        Token(_box)
    }
}

// Method declared in constrained extension — the pattern under test
extension Outer.Inner.Cell.Token where T: ~Copyable {
    public func take() -> T {
        _box.take()
    }
}
