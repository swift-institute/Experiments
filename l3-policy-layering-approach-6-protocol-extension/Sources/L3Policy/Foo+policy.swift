@_exported public import L2Methods

// Approach 6 hypothesis: L3 adds a protocol-extension default that "wraps"
// the conforming type's static method. Test whether protocol-extension
// dispatch can shadow type-extension dispatch.

public protocol FooPolicy {
    static func makeWithPolicy() throws(FooError) -> Foo
}

extension FooPolicy where Self: FooMaker {
    // Forwards to the type's own make() with a wrapping tag.
    public static func makeWithPolicy() throws(FooError) -> Foo {
        let underlying = try Self.make()
        return Foo(tag: "L3-protocol(\(underlying.tag))")
    }
}

extension Foo: FooPolicy {}
