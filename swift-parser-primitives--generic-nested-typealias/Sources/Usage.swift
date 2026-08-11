// Usage: access `Protocol` typealias without specifying E
public func requiresLocated<T: Parser.Error.Located.`Protocol`>(_ value: T) {
    print("offset: \(value.offset)")
}
