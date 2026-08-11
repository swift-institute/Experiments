extension Parser {
    /// Minimal single-parser combinator (Map-shape) wrapping an upstream parser.
    /// Mirrors production `Parser.Map.Transform` at
    /// `swift-parser-primitives/Sources/Parser Map Primitives/Parser.Map.Transform.swift`
    /// but declared `~Copyable` with `Upstream: ~Copyable` per Option α.
    ///
    /// This is the **composed** wrapper that triggered the original SIGSEGV
    /// pattern at production: a Parser.`Protocol` conformer wrapping
    /// another Parser.`Protocol` conformer, instantiated cross-module.
    public struct Map<Upstream: ~Copyable & Parser.`Protocol`, Output>: ~Copyable {
        @usableFromInline
        internal let upstream: Upstream

        @usableFromInline
        internal let transform: (Upstream.Output) -> Output

        @inlinable
        public init(
            upstream: consuming Upstream,
            transform: @escaping (Upstream.Output) -> Output
        ) {
            self.upstream = upstream
            self.transform = transform
        }
    }
}

extension Parser.Map: Parser.`Protocol` where Upstream: ~Copyable {
    public typealias Input = Upstream.Input
    public typealias Failure = Upstream.Failure

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        transform(try upstream.parse(&input))
    }
}
