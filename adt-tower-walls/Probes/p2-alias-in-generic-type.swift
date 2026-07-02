// p2: generic typealias nested in a GENERIC type mixing outer+inner params (the literal Tree.N shape).
// Result (Apple Swift 6.3.3, 2026-07-02): PASSES — outer+inner param mix compiles+runs.
public struct Pair<A: ~Copyable, B: ~Copyable>: ~Copyable { public init() {} }
public struct Impl2<S: ~Copyable>: ~Copyable { public init() {} }
extension Impl2 where S: ~Copyable {
    public typealias With<T: ~Copyable> = Impl2<Pair<S, T>>
}
let w: Impl2<Int>.With<Int> = Impl2<Pair<Int, Int>>()
print("p2 ok:", type(of: w))
