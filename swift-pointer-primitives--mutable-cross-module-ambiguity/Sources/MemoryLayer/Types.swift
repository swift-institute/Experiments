// ===----------------------------------------------------------------------===//
// MemoryLayer: Minimal reproduction of memory-primitives types
// ===----------------------------------------------------------------------===//

// --- Ordinal ---
public struct Ordinal: Copyable, Sendable, Equatable {
    public let rawValue: UInt
    @inlinable public init(_ rawValue: UInt) { self.rawValue = rawValue }
}

// --- Tagged ---
public struct Tagged<Tag: ~Copyable, RawValue: Copyable & Sendable>: Copyable, Sendable {
    public let rawValue: RawValue

    @inlinable
    public init(__unchecked: (), _ rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

extension Tagged: Equatable where RawValue: Equatable {}
extension Tagged: Hashable where RawValue: Hashable {}

// --- Memory namespace ---
public enum Memory {
    public enum Mutable {}
}

// --- Memory.Address = Tagged<Memory, Ordinal> ---
extension Memory {
    public typealias Address = Tagged<Memory, Ordinal>
}

// --- Memory.Address.Mutable = Tagged<Memory.Mutable, Ordinal> ---
extension Tagged where Tag == Memory, RawValue == Ordinal {
    public typealias Mutable = Tagged<Memory.Mutable, Ordinal>
}

// --- Memory.Address operations ---
extension Tagged where Tag == Memory, RawValue == Ordinal {
    @inlinable
    public init(_ pointer: UnsafeRawPointer) {
        self.init(__unchecked: (), Ordinal(UInt(bitPattern: pointer)))
    }

    @inlinable
    public init<T>(_ pointer: UnsafePointer<T>) {
        unsafe self.init(UnsafeRawPointer(pointer))
    }
}

// --- Memory.Address.Mutable operations ---
extension Tagged where Tag == Memory.Mutable, RawValue == Ordinal {
    @inlinable
    public init(_ pointer: UnsafeMutableRawPointer) {
        self.init(__unchecked: (), Ordinal(UInt(bitPattern: pointer)))
    }

    @inlinable
    public init<T>(_ pointer: UnsafeMutablePointer<T>) {
        unsafe self.init(UnsafeMutableRawPointer(pointer))
    }

    @inlinable
    public var asMutableRawPointer: UnsafeMutableRawPointer {
        unsafe UnsafeMutableRawPointer(bitPattern: rawValue.rawValue)!
    }

    @inlinable
    public func assuming<T: ~Copyable>(boundTo type: T.Type) -> UnsafeMutablePointer<T> {
        unsafe asMutableRawPointer.assumingMemoryBound(to: type)
    }
}
