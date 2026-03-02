import TaggedLib

public typealias Char = UInt8

// Reproduction of Memory_Primitives_Core.Memory.Contiguous<Element>
// See: swift-memory-primitives/Sources/Memory Primitives Core/Memory.Contiguous.swift

public enum Memory {}

extension Memory {
    @safe
    public struct Contiguous<Element: BitwiseCopyable>: ~Copyable, @unchecked Sendable {
        @usableFromInline
        internal let pointer: UnsafePointer<Element>

        public let count: Int

        @inlinable
        public init(adopting pointer: UnsafeMutablePointer<Element>, count: Int) {
            unsafe self.pointer = UnsafePointer(pointer)
            self.count = count
        }

        @unsafe
        @inlinable
        public var unsafeBaseAddress: UnsafePointer<Element> { unsafe pointer }

        public var span: Span<Element> {
            @_lifetime(borrow self)
            @inlinable
            borrowing get {
                let s = unsafe Span(_unsafeStart: pointer, count: count)
                return unsafe _overrideLifetime(s, borrowing: self)
            }
        }

        @inlinable
        deinit {
            unsafe UnsafeMutablePointer(mutating: pointer).deallocate()
        }
    }
}
