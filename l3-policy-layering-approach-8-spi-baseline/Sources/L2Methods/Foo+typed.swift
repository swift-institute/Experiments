@_exported public import L1Defs

extension Foo {
    @_spi(Syscall)
    public static func make() throws(FooError) -> Foo {
        return Foo(tag: "L2")
    }
}
