// Simulates swift-path-primitives Path.View type

extension Path {
    @safe
    public struct View: ~Copyable, ~Escapable {
        public let pointer: UnsafePointer<UInt8>
        public let count: Int

        @inlinable
        @_lifetime(borrow pointer)
        public init(pointer: UnsafePointer<UInt8>, count: Int) {
            unsafe (self.pointer = pointer)
            self.count = count
        }

        @inlinable
        public var span: Span<UInt8> {
            @_lifetime(copy self)
            borrowing get {
                let s = unsafe Span(_unsafeStart: pointer, count: count)
                return unsafe _overrideLifetime(s, copying: self)
            }
        }
    }
}
