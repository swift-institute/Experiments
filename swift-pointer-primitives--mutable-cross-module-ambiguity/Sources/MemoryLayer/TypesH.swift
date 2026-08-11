// ===----------------------------------------------------------------------===//
// MemoryLayer Variant H: Move the mutable address typealias from Tagged
// to the Memory.Mutable enum
//
// Key change: Memory.Mutable.Address instead of Memory.Address.Mutable
// This puts the name on an enum, not on Tagged, avoiding the collision.
// ===----------------------------------------------------------------------===//

#if VARIANT_H

// --- Ordinal (shared) ---
public struct OrdinalH: Copyable, Sendable, Equatable {
    public let rawValue: UInt
    @inlinable public init(_ rawValue: UInt) { self.rawValue = rawValue }
}

// --- Tagged (shared) ---
public struct TaggedH<Tag: ~Copyable, RawValue: Copyable & Sendable>: Copyable, Sendable {
    public let rawValue: RawValue

    @inlinable
    public init(__unchecked: (), _ rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

extension TaggedH: Equatable where RawValue: Equatable {}
extension TaggedH: Hashable where RawValue: Hashable {}

// --- Memory namespace ---
public enum MemoryH {
    public enum Mutable {}
}

// --- Memory.Address = Tagged<Memory, Ordinal> ---
extension MemoryH {
    public typealias Address = TaggedH<MemoryH, OrdinalH>
}

// --- KEY CHANGE: Memory.Mutable.Address = Tagged<Memory.Mutable, Ordinal> ---
// This is on the Memory.Mutable enum, NOT on a Tagged extension.
extension MemoryH.Mutable {
    public typealias Address = TaggedH<MemoryH.Mutable, OrdinalH>
}

// --- Memory.Address operations ---
extension TaggedH where Tag == MemoryH, RawValue == OrdinalH {
    // NO Mutable typealias here anymore!

    @inlinable
    public init(_ pointer: UnsafeRawPointer) {
        self.init(__unchecked: (), OrdinalH(UInt(bitPattern: pointer)))
    }

    @inlinable
    public init<T>(_ pointer: UnsafePointer<T>) {
        unsafe self.init(UnsafeRawPointer(pointer))
    }
}

// --- Memory.Mutable.Address operations ---
extension TaggedH where Tag == MemoryH.Mutable, RawValue == OrdinalH {
    @inlinable
    public init(_ pointer: UnsafeMutableRawPointer) {
        self.init(__unchecked: (), OrdinalH(UInt(bitPattern: pointer)))
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

    // Conversion to immutable
    @inlinable
    public var immutable: MemoryH.Address {
        MemoryH.Address(__unchecked: (), rawValue)
    }
}

#endif
