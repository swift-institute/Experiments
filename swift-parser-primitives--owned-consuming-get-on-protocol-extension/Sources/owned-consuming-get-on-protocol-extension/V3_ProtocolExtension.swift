//
// V3 — Protocol extension with @_owned consuming get returning Transform<Self>
//
// Shape: Protocol P: ~Copyable; conforming generic struct V3_Container<T>: P, ~Copyable;
//        @_owned var transform: V3_Transform<Self> { consuming get { V3_Transform(self) } }
//        defined in an `extension P where Self: ~Copyable`.
// Purpose: directly analogous to `Parser.\`Protocol\`.error`. THIS is the production
//          case we care about.
//

public protocol V3_Protocol: ~Copyable {
    associatedtype Token
    consuming func emit() -> Token
}

// The transformer wrapper, parameterised by the conforming Self.
public struct V3_Transform<Upstream: V3_Protocol & ~Copyable>: ~Copyable {
    @usableFromInline
    let upstream: Upstream

    @inlinable
    public init(_ upstream: consuming Upstream) {
        self.upstream = upstream
    }

    @inlinable
    public consuming func tokenize() -> Upstream.Token {
        upstream.emit()
    }
}

// The accessor defined on the protocol extension — this is the production shape
// we want to preserve from Parser.Error.swift line 53-54.
extension V3_Protocol where Self: ~Copyable {
    @_owned
    public var transform: V3_Transform<Self> {
        consuming get {
            V3_Transform(self)
        }
    }
}

// A concrete generic conformer.
public struct V3_Container<T>: V3_Protocol, ~Copyable {
    @usableFromInline
    let value: T

    @inlinable
    public init(_ value: T) {
        self.value = value
    }

    @inlinable
    public consuming func emit() -> T {
        value
    }
}

// Wrapper that takes Self by consuming parameter — mirrors prior research's
// observation that consuming-parameter wrappers sometimes side-step the
// "borrowed by a non-Escapable type" diagnostic.
@inlinable
public func extractV3Transform<P: V3_Protocol & ~Copyable>(_ p: consuming P) -> V3_Transform<P> {
    p.transform
}

@inlinable
public func runV3() -> Int {
    let c = V3_Container<Int>(42)
    let t = extractV3Transform(c)
    return t.tokenize() // 42
}
