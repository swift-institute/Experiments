// PathDomain module: Path type with Char and View (mirrors path-primitives)

public import Core

public struct MyPath: ~Copyable, @unchecked Sendable {
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

extension MyPath {
    public typealias Char = UInt8
}

extension MyPath {
    @safe
    public struct View: ~Copyable, ~Escapable {
        public let pointer: UnsafePointer<Char>
        public let count: Int

        @inlinable
        @_lifetime(borrow pointer)
        public init(_ pointer: UnsafePointer<MyPath.Char>, count: Int) {
            unsafe (self.pointer = pointer)
            self.count = count
        }
    }
}

extension MyPath: Viewable {}
