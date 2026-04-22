// V2: Five verbs, five nearly-identical proxies.
//
// Each proxy is structurally identical: one stored `base`, one initializer,
// one re-export so extensions can mutate it. The only unique part is the
// name of the type. The boilerplate is the point.

public struct Stack<Element> {
    @usableFromInline
    var _storage: [Element] = []

    public init() {}
}

// MARK: - Five proxies, all structurally identical

extension Stack {
    public struct Push {
        @usableFromInline var base: Stack<Element>
        @inlinable init(_ base: consuming Stack<Element>) { self.base = base }
    }
    public struct Pop {
        @usableFromInline var base: Stack<Element>
        @inlinable init(_ base: consuming Stack<Element>) { self.base = base }
    }
    public struct Peek {
        @usableFromInline var base: Stack<Element>
        @inlinable init(_ base: consuming Stack<Element>) { self.base = base }
    }
    public struct ForEach {
        @usableFromInline var base: Stack<Element>
        @inlinable init(_ base: consuming Stack<Element>) { self.base = base }
    }
    public struct Remove {
        @usableFromInline var base: Stack<Element>
        @inlinable init(_ base: consuming Stack<Element>) { self.base = base }
    }
}

// MARK: - Five accessor properties, all performing the same five-step dance

extension Stack {
    public var push: Push {
        _read { yield Push(self) }
        _modify {
            var proxy = Push(consume self)
            self = Stack()
            defer { self = proxy.base }
            yield &proxy
        }
    }

    public var pop: Pop {
        _read { yield Pop(self) }
        _modify {
            var proxy = Pop(consume self)
            self = Stack()
            defer { self = proxy.base }
            yield &proxy
        }
    }

    public var peek: Peek {
        _read { yield Peek(self) }
        _modify {
            var proxy = Peek(consume self)
            self = Stack()
            defer { self = proxy.base }
            yield &proxy
        }
    }

    public var forEach: ForEach {
        _read { yield ForEach(self) }
        _modify {
            var proxy = ForEach(consume self)
            self = Stack()
            defer { self = proxy.base }
            yield &proxy
        }
    }

    public var remove: Remove {
        _read { yield Remove(self) }
        _modify {
            var proxy = Remove(consume self)
            self = Stack()
            defer { self = proxy.base }
            yield &proxy
        }
    }
}

// MARK: - Extensions on each proxy

extension Stack.Push {
    public mutating func back(_ e: Element) {
        base._storage.append(e)
    }
}

extension Stack.Pop {
    public mutating func front() -> Element? {
        base._storage.isEmpty ? nil : base._storage.removeFirst()
    }
}

extension Stack.Peek where Element: Copyable {
    public var front: Element? {
        base._storage.first
    }
}

@main
enum Main {
    static func main() {
        var stack = Stack<Int>()
        stack.push.back(1)
        stack.push.back(2)
        stack.push.back(3)
        print("V2 stack:", stack._storage)

        let head = stack.peek.front
        print("V2 peek.front:", head ?? -1)

        let popped = stack.pop.front()
        print("V2 pop.front:", popped ?? -1, "remaining:", stack._storage)

        // The boilerplate in this file is what the walkthrough factors out
        // in V3. Count the number of times `var base: Stack<Element>` and
        // the five-step `_modify` dance appear.
    }
}
