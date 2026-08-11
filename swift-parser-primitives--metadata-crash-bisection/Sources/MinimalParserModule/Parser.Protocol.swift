extension Parser {
    public protocol `Protocol`<Input, Output, Failure> {
        associatedtype Input: ~Escapable
        associatedtype Output
        associatedtype Failure: Swift.Error & Sendable
        func parse(_ input: inout Input) throws(Failure) -> Output
    }
}
