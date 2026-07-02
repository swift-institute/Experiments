// p1b: VALUE-GENERIC typealias nested in a namespace (the Tree.N<n> SIGSEGV shape, namespaced form).
// Result (Apple Swift 6.3.3, 2026-07-02): PASSES — the 6.3.2-era namespaced value-generic-alias SIGSEGV shape compiles+runs (Wall 4 FIXED in this reduction).
public struct VG<E: ~Copyable, let n: Int>: ~Copyable { public init() {} }
public enum NS2 {}
extension NS2 { public typealias B<E, let n: Int> = VG<E, n> }
let b: NS2.B<Int, 4> = VG()
print("p1b ok:", MemoryLayout<NS2.B<Int, 4>>.size)
