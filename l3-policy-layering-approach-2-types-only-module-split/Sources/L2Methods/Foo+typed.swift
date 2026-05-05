@_exported public import L2Types

// Methods sub-module — extends Foo with the typed Phase 1.5 method.
extension Foo {
    public static func make() throws(FooError) -> Foo {
        return Foo(tag: "L2")
    }
}
