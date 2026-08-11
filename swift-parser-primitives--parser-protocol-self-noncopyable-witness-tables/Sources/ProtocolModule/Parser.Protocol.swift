extension Parser {
    /// Minimal Parser.Protocol matching production swift-parser-primitives
    /// at swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift:90,
    /// PLUS the proposed Option α relaxation: `Self: ~Copyable`.
    ///
    /// Tests whether adding `: ~Copyable` to Self introduces a cross-module
    /// witness-table SIGSEGV at instantiation time, per the pattern documented
    /// at `swift-parser-primitives/Research/witness-table-sigsegv-with-noncopyable-protocol-constraints.md`.
    public protocol `Protocol`<Input, Output, Failure>: ~Copyable {
        associatedtype Input: ~Copyable & ~Escapable
        associatedtype Output
        associatedtype Failure: Swift.Error

        func parse(_ input: inout Input) throws(Failure) -> Output
    }
}
