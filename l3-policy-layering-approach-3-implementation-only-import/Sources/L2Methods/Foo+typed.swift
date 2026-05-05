@_exported public import L1Defs

extension Foo {
    public static func make() throws(FooError) -> Foo {
        return Foo(tag: "L2")
    }
}
