// p1: generic typealias nested in a NON-generic namespace enum + use. Expect: compiles (probe).
// Result (Apple Swift 6.3.3, 2026-07-02): PASSES — compiles+runs.
public struct Node<E: ~Copyable>: ~Copyable { public var e: E; public init(e: consuming E) { self.e = e } }
public struct Impl<S: ~Copyable>: ~Copyable { public var s: S; public init(s: consuming S) { self.s = s } }
public enum NS {}
extension NS { public typealias A<E> = Impl<Node<E>> }
let a: NS.A<Int> = Impl(s: Node(e: 1))
print("p1 ok:", a.s.e)
