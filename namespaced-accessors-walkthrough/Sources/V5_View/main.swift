// V5: Wrapper.View — the pointer-backed variant for ~Copyable bases.
//
// Swap `var base: Base` for `let _base: UnsafeMutablePointer<Base>`. The
// View has no owned storage; it wraps a pointer to someone else's base.
// `~Copyable, ~Escapable` keeps the view from being duplicated or
// outliving its source scope. `@_lifetime(borrow base)` ties its
// lifetime to the pointer's borrow.
//
// `mutating _read` yields the view with a pointer to `&self`. The
// coroutine's scope bounds the view's lifetime.

public struct Wrapper<Tag, Base: ~Copyable>: ~Copyable {
    @usableFromInline
    var base: Base

    @inlinable
    public init(_ base: consuming Base) {
        self.base = base
    }
}

extension Wrapper where Base: ~Copyable {
    public struct View: ~Copyable, ~Escapable {
        @usableFromInline
        let _base: UnsafeMutablePointer<Base>

        @inlinable
        @_lifetime(borrow base)
        public init(_ base: UnsafeMutablePointer<Base>) {
            unsafe self._base = base
        }

        @inlinable
        public var base: UnsafeMutablePointer<Base> {
            unsafe _base
        }
    }
}

public struct Ring: ~Copyable {
    @usableFromInline
    var _storage: [Int] = []

    public init() {}

    @usableFromInline
    mutating func _pushBack(_ element: Int) {
        _storage.append(element)
    }

    @usableFromInline
    mutating func _popFront() -> Int? {
        _storage.isEmpty ? nil : _storage.removeFirst()
    }
}

extension Ring {
    public enum Push {}
    public enum Pop {}

    public var push: Wrapper<Push, Ring>.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view = unsafe Wrapper<Push, Ring>.View(&self)
            yield &view
        }
    }

    public var pop: Wrapper<Pop, Ring>.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view = unsafe Wrapper<Pop, Ring>.View(&self)
            yield &view
        }
    }
}

extension Wrapper.View where Tag == Ring.Push, Base == Ring, Base: ~Copyable {
    public mutating func back(_ element: Int) {
        unsafe base.pointee._pushBack(element)
    }
}

extension Wrapper.View where Tag == Ring.Pop, Base == Ring, Base: ~Copyable {
    public mutating func front() -> Int? {
        unsafe base.pointee._popFront()
    }
}

@main
enum Main {
    static func main() {
        var ring = Ring()
        ring.push.back(1)
        ring.push.back(2)
        ring.push.back(3)
        print("V5 ring:", ring._storage)

        let popped = ring.pop.front()
        print("V5 pop.front:", popped ?? -1, "remaining:", ring._storage)

        // The call-site shape `ring.push.back(…)` is identical to V1–V3's
        // `stack.push.back(…)`. The ownership difference is absorbed by
        // Wrapper.View (pointer-backed) vs Wrapper (value-owning), not by
        // the API the caller sees.
    }
}
