// Concrete heap-backed storage; Element fixed to Int to isolate storage genericity.
public struct HeapStorage: StorageProtocol, ~Copyable {
    public typealias Element = Int
    public let capacity: Int
    @usableFromInline let base: UnsafeMutablePointer<Int>

    public init(capacity: Int) {
        self.capacity = capacity
        self.base = UnsafeMutablePointer<Int>.allocate(capacity: capacity)
    }

    public func pointer(at slot: Int) -> UnsafeMutablePointer<Int> {
        base.advanced(by: slot)
    }

    deinit { base.deallocate() }
}
