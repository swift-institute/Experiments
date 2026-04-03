public struct Container<Element: ~Copyable>: ~Copyable {
    public var ptr: UnsafeMutablePointer<Element>
    public var count: Int

    public init(capacity: Int) {
        ptr = .allocate(capacity: capacity)
        count = 0
    }

    public mutating func append(_ element: consuming Element) {
        (ptr + count).initialize(to: element)
        count += 1
    }

    deinit {
        ptr.deinitialize(count: count)
        ptr.deallocate()
    }
}
