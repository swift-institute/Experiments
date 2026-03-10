// MARK: - Conditional Sequence Conformance
// This conformance is in a separate file from Container's definition.
// The poisoning still occurs because the compiler resolves constraints
// at the module level, not the file level.

extension Container: Sequence where Element: Copyable {
    struct Iterator: IteratorProtocol {
        var current: Int
        let end: Int
        let base: UnsafeMutablePointer<Element>
        mutating func next() -> Element? {
            guard current < end else { return nil }
            defer { current += 1 }
            return base[current]
        }
    }
    func makeIterator() -> Iterator {
        Iterator(current: 0, end: count, base: storage)
    }
}
