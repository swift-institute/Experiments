// Simulate consumer code — can they use the typealias path?

// Variant 1: Conformance declaration via typealias path
struct MyError: Swift.Error, Sendable {
    let offset: Int
}

extension MyError: Parser.Error.Located.`Protocol` {}

// Variant 2: Generic constraint via typealias path
func printOffset<T: Parser.Error.Located.`Protocol`>(_ value: T) {
    print("consumer offset: \(value.offset)")
}

// Variant 3: Existential via typealias path
func takeAny(_ value: any Parser.Error.Located.`Protocol`) {
    print("any offset: \(value.offset)")
}
