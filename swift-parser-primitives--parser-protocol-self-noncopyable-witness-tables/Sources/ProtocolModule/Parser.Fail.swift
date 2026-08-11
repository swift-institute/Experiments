extension Parser {
    /// Minimal leaf parser conforming to `Parser.\`Protocol\``.
    /// Mirrors production `Parser.Fail` at
    /// `swift-parser-primitives/Sources/Parser Fail Primitives/Parser.Fail.swift`
    /// but declared `~Copyable` per Option α.
    public struct Fail<Input: ~Copyable & ~Escapable, Output, F: Swift.Error>: ~Copyable {
        @usableFromInline
        let error: F

        @inlinable
        public init(_ error: F) {
            self.error = error
        }
    }
}

extension Parser.Fail: Parser.`Protocol` where Input: ~Copyable & ~Escapable {
    public typealias Failure = F

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        throw error
    }
}
