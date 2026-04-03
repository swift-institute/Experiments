public import StorageLib

public struct Buffer<Element: ~Copyable, let N: Int>: ~Copyable {
    public var header: Int
    public var storage: InlineStorage<Element, N>
    // NO deinit — cleanup via consuming removeAll()

    @inlinable
    public init() {
        header = 0
        storage = InlineStorage<Element, N>()
    }

    // Consuming: takes ownership of buffer, cleans up storage
    @inlinable
    public consuming func removeAll() {
        storage.cleanup()  // consuming chain
    }
}
