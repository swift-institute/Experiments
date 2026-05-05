@_exported public import L2Methods

extension Foo {
    public enum Policy {}
}

extension Foo.Policy {
    public static func make() throws(FooError) -> Foo {
        let l2 = try Foo.make()
        return Foo(tag: "L3.Policy(\(l2.tag))")
    }
}
