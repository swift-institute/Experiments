// V01-copy-propagation-lib: Cross-module types for CopyPropagation crash reproduction
// Provides InlineStorage, HeapStorage, NCElement for V01-copy-propagation

/// Minimal ~Copyable element type with non-trivial destructor.
public struct NCElement: ~Copyable {
    public var value: Int

    @inlinable
    public init(_ value: Int) {
        self.value = value
    }

    deinit {}
}

/// Minimal fixed-capacity storage, generic over ~Copyable Element.
public struct InlineStorage<Element: ~Copyable>: ~Copyable {
    @usableFromInline
    let buffer: UnsafeMutablePointer<Element>

    public let capacity: Int

    @inlinable
    public init(capacity: Int) {
        self.buffer = .allocate(capacity: capacity)
        self.capacity = capacity
    }

    @inlinable
    public func initialize(to element: consuming Element, at index: Int) {
        unsafe buffer.advanced(by: index).initialize(to: element)
    }

    @inlinable
    public func move(at index: Int) -> Element {
        unsafe buffer.advanced(by: index).move()
    }

    @inlinable
    public func deinitialize(at index: Int) {
        unsafe buffer.advanced(by: index).deinitialize(count: 1)
    }

    deinit {
        buffer.deallocate()
    }
}

/// Minimal heap storage (class reference), generic over ~Copyable Element.
public final class HeapStorage<Element: ~Copyable>: @unchecked Sendable {
    @usableFromInline
    let buffer: UnsafeMutablePointer<Element>

    @usableFromInline
    var count: Int

    @usableFromInline
    let capacity: Int

    @inlinable
    public init(capacity: Int) {
        self.buffer = .allocate(capacity: capacity)
        self.count = 0
        self.capacity = capacity
    }

    @inlinable
    public func append(_ element: consuming Element) {
        unsafe buffer.advanced(by: count).initialize(to: element)
        count += 1
    }

    deinit {
        for i in 0..<count {
            unsafe buffer.advanced(by: i).deinitialize(count: 1)
        }
        buffer.deallocate()
    }
}
