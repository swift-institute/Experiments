// Tagged<Tag, Wrapped> — analogous to Tagged_Primitives.Tagged

public struct Tagged<Tag, Wrapped> {
    public var wrapped: Wrapped

    @inlinable
    public init(_ wrapped: Wrapped) {
        self.wrapped = wrapped
    }
}
