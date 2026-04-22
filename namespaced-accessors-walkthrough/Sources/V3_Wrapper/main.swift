// V3: A discriminated wrapper.
//
// The five proxies of V2 were structurally identical; the difference
// between `Push` and `Pop` was a compile-time label. Here we factor that
// label into a generic `Tag` parameter on one `Wrapper` type. Empty-enum
// tags carry the discrimination; Swift treats `Wrapper<Push, Stack<Int>>`
// and `Wrapper<Pop, Stack<Int>>` as distinct types.

public struct Wrapper<Tag, Base> {
    @usableFromInline
    var base: Base

    @inlinable
    public init(_ base: consuming Base) {
        self.base = base
    }
}

public struct Stack<Element> {
    @usableFromInline
    var _storage: [Element] = []

    public init() {}
}

// MARK: - Tags as empty, compile-time-only enums

extension Stack {
    public enum Push {}
    public enum Pop {}
    public enum Peek {}
    public enum ForEach {}
    public enum Remove {}
}

// MARK: - Accessors

extension Stack {
    public var push: Wrapper<Push, Stack<Element>> {
        _read { yield Wrapper(self) }
        _modify {
            var proxy = Wrapper<Push, Stack<Element>>(consume self)
            self = Stack()
            defer { self = proxy.base }
            yield &proxy
        }
    }

    public var pop: Wrapper<Pop, Stack<Element>> {
        _read { yield Wrapper(self) }
        _modify {
            var proxy = Wrapper<Pop, Stack<Element>>(consume self)
            self = Stack()
            defer { self = proxy.base }
            yield &proxy
        }
    }
}

// MARK: - Extensions constrained on the tag
//
// Methods can introduce their own generic parameters (<E>), so these bind
// the element type via a method-level generic plus a where-clause.
// Property-case extensions (e.g. `peek.front` as a `var` returning `E?`)
// don't compose the same way — Swift doesn't permit property-level generic
// parameters — which is what motivates the sibling `.Typed` variant in the
// real library. V3 stops at the method case.

extension Wrapper {
    public mutating func back<E>(_ element: E)
    where Tag == Stack<E>.Push, Base == Stack<E> {
        base._storage.append(element)
    }

    public mutating func front<E>() -> E?
    where Tag == Stack<E>.Pop, Base == Stack<E> {
        base._storage.isEmpty ? nil : base._storage.removeFirst()
    }
}

@main
enum Main {
    static func main() {
        var stack = Stack<Int>()
        stack.push.back(1)
        stack.push.back(2)
        stack.push.back(3)
        print("V3 stack:", stack._storage)

        let popped: Int? = stack.pop.front()
        print("V3 pop.front:", popped ?? -1, "remaining:", stack._storage)

        // The storage plumbing is written once, in Wrapper. Five tags +
        // two accessor properties + two extension blocks. A third-party
        // library could add a new tag + accessor + extension without
        // ever touching Wrapper or Stack's source.
    }
}
