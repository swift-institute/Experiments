public struct Foo: Sendable, Equatable {
    public let tag: String
    public init(tag: String) {
        self.tag = tag
    }
}

public enum FooError: Error, Sendable {
    case failed
}

public protocol FooMaker {
    static func make() throws(FooError) -> Foo
}
