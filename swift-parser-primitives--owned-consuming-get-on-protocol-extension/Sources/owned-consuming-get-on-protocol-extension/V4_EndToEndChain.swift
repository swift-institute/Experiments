//
// V4 — Full end-to-end: parser.error.map { ... } chain analog
//
// Shape: Models the production `parser.error.map { transform } → Map<Parser, NewError>`
//        chain with all types ~Copyable. `Map` conforms to P. The chain exercises
//        BOTH the protocol-extension `@_owned consuming get` (the `.error` site)
//        AND a downstream method that consumes the resulting Transform to build a
//        new conformer.
// Purpose: verify the production composition syntax compiles end-to-end.
//

// Re-use V3_Protocol — share the protocol so V4 builds on V3.

// Failure error type stand-in.
public enum V4_Failure: Swift.Error {
    case unsupported
}

public enum V4_NewFailure: Swift.Error {
    case mapped(Int)
}

// Stand-in for the production `Parser.Error.Transform<Upstream>` —
// note we re-declare here to model the .map step (V3's V3_Transform was minimal).
public struct V4_ErrorTransform<Upstream: V3_Protocol & ~Copyable>: ~Copyable {
    @usableFromInline
    let upstream: Upstream

    @inlinable
    public init(_ upstream: consuming Upstream) {
        self.upstream = upstream
    }

    // The terminal combinator: consume the Transform, fold in the error
    // mapping closure, and return a new conforming wrapper.
    @inlinable
    public consuming func map<NewFailure: Swift.Error>(
        _ transform: @escaping (V4_Failure) -> NewFailure
    ) -> V4_Map<Upstream, NewFailure> {
        // `consuming` rebinding pattern — same as production `Map(upstream, transform: transform)`.
        let captured = upstream
        return V4_Map(captured, transform: transform)
    }
}

// The downstream Map conformer.
public struct V4_Map<Upstream: V3_Protocol & ~Copyable, NewFailure: Swift.Error>: ~Copyable {
    @usableFromInline
    let upstream: Upstream

    @usableFromInline
    let transform: (V4_Failure) -> NewFailure

    @inlinable
    public init(
        _ upstream: consuming Upstream,
        transform: @escaping (V4_Failure) -> NewFailure
    ) {
        self.upstream = upstream
        self.transform = transform
    }
}

extension V4_Map: V3_Protocol where Upstream: ~Copyable {
    public typealias Token = Upstream.Token

    @inlinable
    public consuming func emit() -> Token {
        upstream.emit()
    }
}

// The .error accessor on the protocol, analogous to Parser.`Protocol`.error.
extension V3_Protocol where Self: ~Copyable {
    @_owned
    public var error: V4_ErrorTransform<Self> {
        consuming get {
            V4_ErrorTransform(self)
        }
    }
}

// Consuming-parameter wrapper for the end-to-end chain.
@inlinable
public func runV4Chain<P: V3_Protocol & ~Copyable>(
    _ p: consuming P
) -> V4_Map<P, V4_NewFailure> {
    p.error.map { _ in V4_NewFailure.mapped(99) }
}

@inlinable
public func runV4() -> Int {
    let c = V3_Container<Int>(7)
    let mapped = runV4Chain(c)
    return mapped.emit() // 7
}
