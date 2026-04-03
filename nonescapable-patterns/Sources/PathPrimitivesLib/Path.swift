// Simulates swift-path-primitives Path type

@safe
public struct Path: ~Copyable {
    @usableFromInline
    internal let pointer: UnsafeMutablePointer<UInt8>

    public let count: Int

    @inlinable
    public init(adopting pointer: UnsafeMutablePointer<UInt8>, count: Int) {
        unsafe (self.pointer = pointer)
        self.count = count
    }

    @inlinable
    public init(_ span: Span<UInt8>) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: span.count + 1)
        for i in 0..<span.count { (unsafe buffer)[i] = span[i] }
        (unsafe buffer)[span.count] = 0
        unsafe (self.pointer = buffer)
        self.count = span.count
    }

    /// Convenience init from a Swift string (for experiments).
    @inlinable
    public init(_ string: Swift.String) {
        let utf8 = Array(string.utf8)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: utf8.count + 1)
        for i in 0..<utf8.count { (unsafe buffer)[i] = utf8[i] }
        (unsafe buffer)[utf8.count] = 0
        unsafe (self.pointer = buffer)
        self.count = utf8.count
    }

    deinit { unsafe pointer.deallocate() }

    @inlinable
    public var view: View {
        @_lifetime(borrow self)
        borrowing get {
            let v = unsafe View(pointer: UnsafePointer(pointer), count: count)
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }

    /// Reads byte at index (for test verification only).
    @inlinable
    public func byte(at index: Int) -> UInt8 {
        unsafe pointer[index]
    }
}
