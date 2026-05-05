// Variant 1a: internal import + public import of same module — does Swift allow?
internal import L2Methods
public import L2Methods

extension Foo {
    public static func make() throws(FooError) -> Foo {
        let l2 = try Foo.make()
        return Foo(tag: "L3(\(l2.tag))")
    }
}
