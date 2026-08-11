extension Parser {
    // NOTE: No ~Escapable on Input — diagnostic experiment
    public protocol `Protocol`<Input, Output, Failure> {
        associatedtype Input
        associatedtype Output
        associatedtype Failure: Swift.Error & Sendable
        func parse(_ input: inout Input) throws(Failure) -> Output
    }
}
