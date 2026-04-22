// V1: One accessor, one bespoke proxy.
//
// The direct implementation of `stack.push.back(_:)` on a Copyable Stack.
// A single `Push` struct owns the stack while the call is in flight.
// The `_modify` accessor performs the five-step dance that preserves
// copy-on-write semantics for Copyable bases.

public struct Stack<Element> {
    @usableFromInline
    var _storage: [Element] = []

    public init() {}
}

extension Stack {
    public struct Push {
        @usableFromInline
        var base: Stack<Element>

        @inlinable
        init(_ base: consuming Stack<Element>) {
            self.base = base
        }
    }

    public var push: Push {
        _read {
            yield Push(self)
        }
        _modify {
            var proxy = Push(consume self)
            self = Stack()
            defer { self = proxy.base }
            yield &proxy
        }
    }
}

extension Stack.Push {
    public mutating func back(_ element: Element) {
        base._storage.append(element)
    }

    public mutating func front(_ element: Element) {
        base._storage.insert(element, at: 0)
    }
}

@main
enum Main {
    static func main() {
        var stack = Stack<Int>()
        stack.push.back(1)
        stack.push.back(2)
        stack.push.front(0)
        print("V1 stack:", stack._storage)
        // Expected: [0, 1, 2]
    }
}
