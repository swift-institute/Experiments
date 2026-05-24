// Concrete storage #1 — heap-backed (models `Storage.Heap`). Element fixed to Int
// to isolate the *storage* genericity from element genericity ([EXP-004] reduction).
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
