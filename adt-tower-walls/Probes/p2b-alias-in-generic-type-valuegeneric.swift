// p2b: value-generic alias nested in a generic type (Tree.N<n> with let n).
// Result (Apple Swift 6.3.3, 2026-07-02): PASSES — the literal Tree.N<let n> shape compiles+runs.
public struct VG2<S: ~Copyable, let n: Int>: ~Copyable { public init() {} }
public struct Impl3<S: ~Copyable>: ~Copyable { public init() {} }
extension Impl3 where S: ~Copyable {
    public typealias N<let n: Int> = Impl3<VG2<S, n>>
}
let t: Impl3<Int>.N<4> = Impl3<VG2<Int, 4>>()
print("p2b ok:", type(of: t))
