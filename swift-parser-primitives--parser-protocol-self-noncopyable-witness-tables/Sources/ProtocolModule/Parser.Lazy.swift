extension Parser {
    /// Minimal Lazy-shape combinator: stores a closure that builds a ~Copyable
    /// parser on each parse call. Mirrors production `Parser.Lazy` shape at
    /// `swift-parser-primitives/Sources/Parser Lazy Primitives/Parser.Lazy.swift`
    /// adapted to ~Copyable Self and ~Copyable P (Option α).
    ///
    /// Tests whether closures returning `~Copyable` values are usable at protocol
    /// composition sites post-SE-0432 / -0497.
    public struct Lazy<P: ~Copyable & Parser.`Protocol`>: ~Copyable {
        @usableFromInline
        internal let build: () -> P

        @inlinable
        public init(_ build: @escaping () -> P) {
            self.build = build
        }
    }
}

extension Parser.Lazy: Parser.`Protocol` where P: ~Copyable {
    public typealias Input = P.Input
    public typealias Output = P.Output
    public typealias Failure = P.Failure

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        try build().parse(&input)
    }
}
