// StringStorage.swift — Owned ~Copyable string storage
// Mirrors String_Primitives.String._storage but as a standalone type.

import TaggedLib

public typealias Char = UInt8

@safe
public struct StringStorage: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let pointer: UnsafePointer<Char>

    public let count: Int

    @inlinable
    public init(adopting pointer: UnsafeMutablePointer<Char>, count: Int) {
        unsafe self.pointer = UnsafePointer(pointer)
        self.count = count
    }

    @inlinable
    deinit {
        unsafe UnsafeMutablePointer(mutating: pointer).deallocate()
    }
}
