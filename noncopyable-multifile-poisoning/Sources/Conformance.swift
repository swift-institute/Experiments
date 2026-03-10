// MARK: - Conditional Sequence Conformance
// Adding this conformance in a separate file still poisons Slab's
// stored properties at the module level.

extension Slab: Sequence where Element: Copyable {
    struct Iterator: IteratorProtocol {
        var index: Int
        let count: Int
        let pointer: UnsafeMutablePointer<Element>
        mutating func next() -> Element? {
            guard index < count else { return nil }
            defer { index += 1 }
            return pointer[index]
        }
    }
    func makeIterator() -> Iterator {
        Iterator(index: 0, count: capacity, pointer: base)
    }
}
