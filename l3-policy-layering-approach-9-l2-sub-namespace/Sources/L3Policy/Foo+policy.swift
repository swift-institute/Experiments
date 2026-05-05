@_exported public import L2Methods

// L3 declares the user-facing method directly on Foo. Body delegates to
// Foo.Syscall.make() — different namespace path, NO collision.
extension Foo {
    public static func make() throws(FooError) -> Foo {
        let l2 = try Foo.Syscall.make()
        return Foo(tag: "L3(\(l2.tag))")
    }
}
