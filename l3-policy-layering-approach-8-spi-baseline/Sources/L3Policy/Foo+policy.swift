@_spi(Syscall) @_exported public import L2Methods

extension Foo {
    public static func make() throws(FooError) -> Foo {
        let l2 = try Foo.make()
        return Foo(tag: "L3(\(l2.tag))")
    }
}
