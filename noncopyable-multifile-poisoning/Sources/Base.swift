// MARK: - Base Type
// Generic struct with ~Copyable element and unsafe storage.
// Defined separately from the conditional conformance.

struct Slab<Element: ~Copyable>: ~Copyable {
    var base: UnsafeMutablePointer<Element>
    var capacity: Int

    init(capacity: Int) {
        self.base = .allocate(capacity: capacity)
        self.capacity = capacity
    }

    deinit {
        base.deallocate()
    }
}
