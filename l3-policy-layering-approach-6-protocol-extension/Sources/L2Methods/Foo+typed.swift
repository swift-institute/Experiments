@_exported public import L1Defs

extension Foo: FooMaker {
    public static func make() throws(FooError) -> Foo {
        return Foo(tag: "L2")
    }
}
