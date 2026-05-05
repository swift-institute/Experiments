@_exported public import L1Defs

// L2 hosts its typed methods at a SUB-NAMESPACE under Foo (Foo.Syscall),
// NOT at Foo directly. This eliminates same-signature collision with L3's
// user-facing methods, while keeping the typed forms accessible to any
// caller who wants the raw spec-literal syscall (Foo.Syscall.make()) instead
// of the policy-wrapped form (Foo.make()).
extension Foo {
    public enum Syscall {}
}

extension Foo.Syscall {
    public static func make() throws(FooError) -> Foo {
        return Foo(tag: "L2.Syscall")
    }
}
