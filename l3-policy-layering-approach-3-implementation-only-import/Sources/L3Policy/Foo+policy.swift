// Approach 3a: @_implementationOnly import — hide L2 from consumers entirely
@_implementationOnly import L2Methods
// L1Defs needed for Foo public re-export to consumers
@_exported public import L1Defs

extension Foo {
    public static func make() throws(FooError) -> Foo {
        let l2 = try Foo.make()
        return Foo(tag: "L3(\(l2.tag))")
    }
}
