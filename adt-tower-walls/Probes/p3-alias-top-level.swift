// p3: top-level generic typealias with a ~Copyable param + use (the consumer-spelling mitigation).
// Result (Apple Swift 6.3.3, 2026-07-02): PASSES — top-level alias with ~Copyable param.
public struct Node3<E: ~Copyable>: ~Copyable { public var e: E; public init(e: consuming E) { self.e = e } }
public struct Impl4<S: ~Copyable>: ~Copyable { public var s: S; public init(s: consuming S) { self.s = s } }
public typealias Arr<E: ~Copyable> = Impl4<Node3<E>>
let x: Arr<Int> = Impl4(s: Node3(e: 2))
print("p3 ok:", x.s.e)
