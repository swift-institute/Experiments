@_exported public import L1Defs

// Types-only sub-module — defines the data type, no methods.
public struct Foo: Sendable, Equatable {
    public let tag: String
    public init(tag: String) {
        self.tag = tag
    }
}

public enum FooError: Error, Sendable {
    case failed
}
