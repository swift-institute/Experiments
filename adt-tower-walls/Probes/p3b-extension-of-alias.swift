// p3b: extending THROUGH a generic typealias. Expect: probe (historically rejected).
// Result (Apple Swift 6.3.3, 2026-07-02): PASSES — extension THROUGH a generic typealias resolves to the underlying type.
public struct Impl5<S: ~Copyable>: ~Copyable { public init() {} }
public typealias Ali<E: ~Copyable> = Impl5<E>
extension Ali where S: ~Copyable {
    public func hello() {}
}
print("p3b ok")
