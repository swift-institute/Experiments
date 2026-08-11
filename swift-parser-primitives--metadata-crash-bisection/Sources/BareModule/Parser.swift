public enum Parser {}

extension Parser {
    // No ~Escapable, no Failure constraint — absolute minimum protocol
    public protocol `Protocol` {
        associatedtype Input
        associatedtype Output
        func parse(_ input: inout Input) -> Output
    }
}

extension Parser {
    public struct Always<Input, Output>: Sendable where Output: Sendable {
        public let output: Output

        @inlinable
        public init(_ output: Output) {
            self.output = output
        }
    }
}

extension Parser.Always: Parser.`Protocol` {
    @inlinable
    public func parse(_ input: inout Input) -> Output {
        output
    }
}
