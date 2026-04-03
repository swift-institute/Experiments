public struct InlineStorage<Element: ~Copyable, let N: Int>: ~Copyable {
    @_rawLayout(likeArrayOf: Element, count: N)
    public struct _Raw: ~Copyable {
        @usableFromInline init() {}
    }

    public var _count: Int
    public var _storage: _Raw

    @inlinable
    public init() { _count = 0; _storage = _Raw() }

    @unsafe @inlinable
    public func pointer(at index: Int) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafePointer(to: _storage) { base in
            unsafe UnsafeMutablePointer(
                mutating: UnsafeRawPointer(base)
                    .advanced(by: index * MemoryLayout<Element>.stride)
                    .assumingMemoryBound(to: Element.self)
            )
        }
    }

    @inlinable
    public mutating func store(_ value: consuming Element, at index: Int) {
        unsafe pointer(at: index).initialize(to: value)
        _count += 1
    }

    // Consuming cleanup — the key pattern
    @inlinable
    public consuming func cleanup() {
        let count = _count
        for i in 0..<count {
            unsafe pointer(at: i).deinitialize(count: 1)
        }
    }
}
