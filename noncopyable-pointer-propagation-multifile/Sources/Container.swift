// MARK: - Base Container Type
// Defined in a separate file from the Sequence conformance to test
// whether file-level separation prevents constraint poisoning.

struct Container<Element: ~Copyable>: ~Copyable {
    var storage: UnsafeMutablePointer<Element>
    var count: Int

    init(capacity: Int) {
        storage = .allocate(capacity: capacity)
        count = 0
    }

    deinit {
        storage.deallocate()
    }
}
