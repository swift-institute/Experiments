// Minimal @_rawLayout storage that mirrors production Storage<Element>.Inline<capacity>.
//
// Production uses @_rawLayout(likeArrayOf: Element, count: capacity) for the raw bytes,
// with a bitvector for slot tracking. This is a simplified version that stores a single
// element (enough to verify deinit fires).
//
// The @_rawLayout attribute is the key ingredient that triggers compiler bug #86652:
// cross-package value-generic ~Copyable structs with @_rawLayout properties don't get
// their member destruction synthesized.

/// Inline storage using @_rawLayout. Mirrors production Storage<Element>.Inline<capacity>.
public struct InlineStorage<Element: ~Copyable, let capacity: Int>: ~Copyable {

    /// Raw bytes — the critical piece. Uses @_rawLayout for automatic layout computation.
    @_rawLayout(likeArrayOf: Element, count: capacity)
    @usableFromInline
    package struct _Raw: ~Copyable {
        @usableFromInline
        init() {}
    }

    @usableFromInline
    package var _storage: _Raw

    @usableFromInline
    package var _count: Int

    /// Creates empty inline storage.
    @inlinable
    public init() {
        _storage = _Raw()
        _count = 0
    }

    /// Returns a mutable pointer to the element at `index`.
    /// The pointer is only valid for the duration of the current mutation.
    @unsafe
    @usableFromInline
    mutating func _elementPointer(at index: Int) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointer(to: &_storage) { raw in
            unsafe UnsafeMutableRawPointer(raw)
                .assumingMemoryBound(to: Element.self)
                .advanced(by: index)
        }
    }

    /// Stores an element at the next available slot.
    @inlinable
    public mutating func append(_ element: consuming Element) {
        precondition(_count < capacity, "InlineStorage: capacity exceeded")
        let ptr = unsafe _elementPointer(at: _count)
        unsafe ptr.initialize(to: element)
        _count += 1
    }

    /// Deinitializes all initialized elements. Mutating version for manual cleanup.
    /// Mirrors production: Storage.Inline.deinitialize() called via mutable pointer.
    @inlinable
    public mutating func deinitializeAll() {
        unsafe withUnsafeMutablePointer(to: &_storage) { raw in
            let base = unsafe UnsafeMutableRawPointer(raw)
                .assumingMemoryBound(to: Element.self)
            for i in 0..<_count {
                unsafe (base + i).deinitialize(count: 1)
            }
        }
        _count = 0
    }

    deinit {
        // Clean up all initialized elements via pointer.
        // This mirrors production: Storage.Inline.deinitialize() iterates slot bits.
        unsafe withUnsafePointer(to: _storage) { raw in
            let base = unsafe UnsafeMutablePointer(
                mutating: UnsafeRawPointer(raw).assumingMemoryBound(to: Element.self)
            )
            for i in 0..<_count {
                unsafe (base + i).deinitialize(count: 1)
            }
        }
    }
}
