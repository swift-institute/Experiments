// L3 re-exports L2Types (so consumers see Foo + FooError) but only
// internally imports L2Methods (so consumers do NOT see L2's make()).
@_exported public import L2Types
internal import L2Methods

extension Foo {
    public static func make() throws(FooError) -> Foo {
        let l2 = try Foo.make()
        return Foo(tag: "L3(\(l2.tag))")
    }
}
