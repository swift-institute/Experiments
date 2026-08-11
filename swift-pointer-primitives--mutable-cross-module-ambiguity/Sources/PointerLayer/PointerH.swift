// ===----------------------------------------------------------------------===//
// PointerLayer Variant H: Only ONE Mutable typealias on Tagged
//
// Memory.Mutable.Address is on the Memory.Mutable enum (not Tagged).
// Pointer<T>.Mutable is the ONLY Mutable on any Tagged extension.
// No collision possible.
// ===----------------------------------------------------------------------===//

#if VARIANT_H

public import MemoryLayer

// --- Pointer<T> = Tagged<T, Memory.Address> ---
public typealias PointerH<Pointee: ~Copyable> = TaggedH<Pointee, MemoryH.Address>

// --- Immutable pointer: base accessor ---
extension TaggedH where RawValue == MemoryH.Address, Tag: ~Copyable {
    @inlinable
    public var baseH: UnsafePointer<Tag> {
        unsafe UnsafeRawPointer(bitPattern: rawValue.rawValue.rawValue)!
            .assumingMemoryBound(to: Tag.self)
    }

    @inlinable
    public init(pointerH: UnsafePointer<Tag>) {
        unsafe self.init(__unchecked: (), MemoryH.Address(pointerH))
    }
}

// --- Pointer<T>.Mutable = Tagged<T, Memory.Mutable.Address> ---
// This is the ONLY Mutable typealias on any TaggedH extension.
extension TaggedH where RawValue == MemoryH.Address, Tag: ~Copyable {
    public typealias Mutable = TaggedH<Tag, MemoryH.Mutable.Address>
}

// --- Mutable pointer operations ---
extension TaggedH where RawValue == MemoryH.Mutable.Address, Tag: ~Copyable {
    @inlinable
    public var baseH: UnsafeMutablePointer<Tag> {
        unsafe rawValue.assuming(boundTo: Tag.self)
    }

    @inlinable
    public init(pointerH: UnsafeMutablePointer<Tag>) {
        unsafe self.init(__unchecked: (), MemoryH.Mutable.Address(pointerH))
    }

    // Return type uses Memory.Mutable.Address — no ambiguity
    @inlinable
    public func deinitializeH() -> MemoryH.Mutable.Address {
        rawValue
    }

    // Parameter uses Pointer<Tag>.Mutable — is this ambiguous?
    @inlinable
    public func initializeH(from source: PointerH<Tag>.Mutable) {
        _ = source.baseH
    }

    // Parameter uses immutable Pointer<Tag>
    @inlinable
    public func initializeFromImmutableH(from source: PointerH<Tag>) {
        _ = source.baseH
    }
}

// --- Immutable pointer referencing Mutable in signature ---
extension TaggedH where RawValue == MemoryH.Address, Tag: Copyable {
    @inlinable
    public func copyH(to destination: PointerH<Tag>.Mutable, count: Int) {
        unsafe destination.baseH.initialize(from: self.baseH, count: count)
    }
}

#endif
