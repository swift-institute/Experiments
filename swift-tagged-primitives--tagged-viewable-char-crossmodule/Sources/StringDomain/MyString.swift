// StringDomain module: String type with Char and View (mirrors string-primitives)

public import Core

public struct MyString: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let pointer: UnsafeMutablePointer<UInt8>
    public let count: Int

    @inlinable
    public init(pointer: UnsafeMutablePointer<UInt8>, count: Int) {
        self.pointer = pointer
        self.count = count
    }

    deinit { pointer.deallocate() }
}

extension MyString {
    public typealias Char = UInt8
}

extension MyString {
    @safe
    public struct View: ~Copyable, ~Escapable {
        public let pointer: UnsafePointer<Char>
        public let count: Int

        @inlinable
        @_lifetime(borrow pointer)
        public init(_ pointer: UnsafePointer<MyString.Char>, count: Int) {
            unsafe (self.pointer = pointer)
            self.count = count
        }
    }
}

extension MyString: Viewable {}
