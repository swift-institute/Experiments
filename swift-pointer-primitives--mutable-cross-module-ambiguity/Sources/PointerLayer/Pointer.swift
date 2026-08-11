// ===----------------------------------------------------------------------===//
// PointerLayer: Cross-module consumer of MemoryLayer
//
// Tests whether Pointer<T>.Mutable typealias on Tagged collides with
// Memory.Address.Mutable typealias on Tagged, cross-module.
// ===----------------------------------------------------------------------===//

public import MemoryLayer

// --- Pointer<T> = Tagged<T, Memory.Address> ---

public typealias Pointer<Pointee: ~Copyable> = Tagged<Pointee, Memory.Address>

// --- Immutable pointer: base accessor (needed by multiple variants) ---
#if !VARIANT_H
extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    @inlinable
    public var base: UnsafePointer<Tag> {
        unsafe UnsafeRawPointer(bitPattern: rawValue.rawValue.rawValue)!
            .assumingMemoryBound(to: Tag.self)
    }

    @inlinable
    public init(_ pointer: UnsafePointer<Tag>) {
        unsafe self.init(__unchecked: (), Memory.Address(pointer))
    }
}
#endif

// ===----------------------------------------------------------------------===//
// MARK: - Variant A: Two Mutable typealiases (current production approach)
//
// Hypothesis: This will FAIL cross-module due to ambiguous .Mutable lookup
// ===----------------------------------------------------------------------===//

#if VARIANT_A

extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    public typealias Immutable = Tagged<Tag, Memory.Address>
    public typealias Mutable = Tagged<Tag, Memory.Address.Mutable>
}

// Extension on Pointer<T>.Mutable (uses Memory.Address.Mutable in constraint)
extension Tagged where RawValue == Memory.Address.Mutable, Tag: ~Copyable {
    @inlinable
    public var base: UnsafeMutablePointer<Tag> {
        unsafe rawValue.assuming(boundTo: Tag.self)
    }

    @inlinable
    public init(_ pointer: UnsafeMutablePointer<Tag>) {
        unsafe self.init(__unchecked: (), Memory.Address.Mutable(pointer))
    }
}

#endif

// ===----------------------------------------------------------------------===//
// MARK: - Variant B: Fully qualify the constraint only
//
// Hypothesis: Qualifying constraint but keeping .Mutable in type refs will
// still fail for type references
// ===----------------------------------------------------------------------===//

#if VARIANT_B

extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    public typealias Immutable = Tagged<Tag, Memory.Address>
    public typealias Mutable = Tagged<Tag, Memory.Address.Mutable>
}

// Constraint uses fully qualified type
extension Tagged where RawValue == Tagged<Memory.Mutable, Ordinal>, Tag: ~Copyable {
    @inlinable
    public var base: UnsafeMutablePointer<Tag> {
        unsafe rawValue.assuming(boundTo: Tag.self)
    }

    @inlinable
    public init(_ pointer: UnsafeMutablePointer<Tag>) {
        // Body still uses Memory.Address.Mutable — will this fail?
        unsafe self.init(__unchecked: (), Memory.Address.Mutable(pointer))
    }

    // Return type uses Memory.Address.Mutable — will this fail?
    @inlinable
    public func deinitialize() -> Memory.Address.Mutable {
        rawValue
    }

    // Parameter uses Pointer<Tag>.Mutable — will this fail?
    @inlinable
    public func initialize(from source: Pointer<Tag>.Mutable) {
        _ = source.base
    }
}

#endif

// ===----------------------------------------------------------------------===//
// MARK: - Variant C: Fully qualify EVERYWHERE
//
// Hypothesis: This WILL compile — no ambiguous .Mutable lookup anywhere
// ===----------------------------------------------------------------------===//

#if VARIANT_C

extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    public typealias Immutable = Tagged<Tag, Memory.Address>
    public typealias Mutable = Tagged<Tag, Tagged<Memory.Mutable, Ordinal>>
}

extension Tagged where RawValue == Tagged<Memory.Mutable, Ordinal>, Tag: ~Copyable {
    @inlinable
    public var base: UnsafeMutablePointer<Tag> {
        unsafe rawValue.assuming(boundTo: Tag.self)
    }

    @inlinable
    public init(_ pointer: UnsafeMutablePointer<Tag>) {
        unsafe self.init(__unchecked: (), Tagged<Memory.Mutable, Ordinal>(pointer))
    }

    @inlinable
    public func deinitialize() -> Tagged<Memory.Mutable, Ordinal> {
        rawValue
    }

    @inlinable
    public func initialize(from source: Tagged<Tag, Tagged<Memory.Mutable, Ordinal>>) {
        _ = source.base
    }
}

#endif

// ===----------------------------------------------------------------------===//
// MARK: - Variant D: Unify — remove pointer-level Mutable typealias entirely
//
// Hypothesis: With only ONE Mutable typealias (on Memory.Address), no ambiguity.
// Pointer<T>.Mutable is NOT available — users spell Tagged<T, Memory.Address.Mutable>
// or use a module-level typealias.
// ===----------------------------------------------------------------------===//

#if VARIANT_D

// No Mutable typealias on the Pointer extension at all.
// Users must spell the full type or use a convenience typealias.
extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    public typealias Immutable = Tagged<Tag, Memory.Address>
    // NO Mutable here
}

// This extension uses Memory.Address.Mutable — should resolve unambiguously
// because there's only ONE Mutable typealias (on Memory.Address).
extension Tagged where RawValue == Memory.Address.Mutable, Tag: ~Copyable {
    @inlinable
    public var base: UnsafeMutablePointer<Tag> {
        unsafe rawValue.assuming(boundTo: Tag.self)
    }

    @inlinable
    public init(_ pointer: UnsafeMutablePointer<Tag>) {
        unsafe self.init(__unchecked: (), Memory.Address.Mutable(pointer))
    }

    @inlinable
    public func deinitialize() -> Memory.Address.Mutable {
        rawValue
    }

    // Without Pointer<Tag>.Mutable, how do we spell it?
    @inlinable
    public func initialize(from source: Tagged<Tag, Memory.Address.Mutable>) {
        _ = source.base
    }
}

#endif

// ===----------------------------------------------------------------------===//
// MARK: - Variant E: Module-level typealias as bridge
//
// Hypothesis: A module-level typealias avoids the .Mutable lookup on Tagged.
// Keep Pointer<T>.Mutable typealias for consumers but use the bridge internally.
// ===----------------------------------------------------------------------===//

#if VARIANT_E

/// Module-level bridge that avoids the ambiguous .Mutable lookup path.
public typealias MutableAddress = Tagged<Memory.Mutable, Ordinal>

extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    public typealias Immutable = Tagged<Tag, Memory.Address>
    public typealias Mutable = Tagged<Tag, MutableAddress>
}

extension Tagged where RawValue == MutableAddress, Tag: ~Copyable {
    @inlinable
    public var base: UnsafeMutablePointer<Tag> {
        unsafe rawValue.assuming(boundTo: Tag.self)
    }

    @inlinable
    public init(_ pointer: UnsafeMutablePointer<Tag>) {
        unsafe self.init(__unchecked: (), MutableAddress(pointer))
    }

    @inlinable
    public func deinitialize() -> MutableAddress {
        rawValue
    }

    @inlinable
    public func initialize(from source: Pointer<Tag>.Mutable) {
        _ = source.base
    }
}

#endif

// ===----------------------------------------------------------------------===//
// MARK: - Variant F: Unify by redefining Pointer<T>.Mutable to use
//                     Memory.Mutable as an inner tag (same tag chain)
//
// Hypothesis: If we define Mutable NOT as a typealias but restructure
// the tag hierarchy so there's only one definition site, no collision.
// This variant uses a marker protocol instead of a second typealias.
// ===----------------------------------------------------------------------===//

#if VARIANT_F

// Define Mutable ONLY at the pointer level via the Memory.Address.Mutable
// that already exists, but provide a convenience typealias that doesn't go
// through .Mutable member lookup on Tagged.
//
// The insight: Pointer<T>.Mutable = Tagged<T, Memory.Address.Mutable>.
// If we write the Mutable typealias definition to NOT use .Mutable member
// access on Memory.Address, but instead directly resolve the underlying type:

extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    public typealias Immutable = Tagged<Tag, Memory.Address>

    // KEY: Define Mutable by resolving Memory.Address.Mutable through the
    // fully-qualified underlying type, NOT through the .Mutable member lookup.
    public typealias Mutable = Tagged<Tag, Tagged<Memory.Mutable, Ordinal>>
}

// Constraint also uses fully-qualified form.
extension Tagged where RawValue == Tagged<Memory.Mutable, Ordinal>, Tag: ~Copyable {
    @inlinable
    public var base: UnsafeMutablePointer<Tag> {
        unsafe rawValue.assuming(boundTo: Tag.self)
    }

    @inlinable
    public init(_ pointer: UnsafeMutablePointer<Tag>) {
        unsafe self.init(__unchecked: (), Tagged<Memory.Mutable, Ordinal>(pointer))
    }

    // Return type: Can we use Memory.Address.Mutable here?
    // This IS inside a Tagged extension, but it's returning the rawValue type
    // which the compiler knows is Tagged<Memory.Mutable, Ordinal>.
    @inlinable
    public func deinitialize() -> Tagged<Memory.Mutable, Ordinal> {
        rawValue
    }

    // Parameter: Can we use Pointer<Tag>.Mutable here?
    // Pointer<Tag> = Tagged<Tag, Memory.Address> = Tagged<Tag, Tagged<Memory, Ordinal>>
    // .Mutable on that — does it still find both?
    @inlinable
    public func initializeFromQualified(from source: Tagged<Tag, Tagged<Memory.Mutable, Ordinal>>) {
        _ = source.base
    }

    // Same but using Pointer<Tag>.Mutable — test if THIS is ambiguous
    @inlinable
    public func initializeFromAlias(from source: Pointer<Tag>.Mutable) {
        _ = source.base
    }
}

#endif

// ===----------------------------------------------------------------------===//
// MARK: - Variant G: Mutable as ad-hoc struct (like Buffer.Mutable)
//
// Hypothesis: If Pointer<T>.Mutable is a STRUCT nested in a Tagged extension
// rather than a TYPEALIAS, it won't collide with Memory.Address.Mutable
// because struct member lookup goes through the struct's namespace, not Tagged's.
//
// This mirrors how Buffer and Buffer.Mutable already work successfully.
// ===----------------------------------------------------------------------===//

#if VARIANT_G

extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    public typealias Immutable = Tagged<Tag, Memory.Address>

    /// Mutable typed pointer as a struct — avoids typealias collision.
    @safe
    public struct Mutable: Copyable, @unchecked Sendable {
        @usableFromInline
        internal let _base: UnsafeMutablePointer<Tag>

        @inlinable
        public var base: UnsafeMutablePointer<Tag> { unsafe _base }

        @inlinable
        public init(_ pointer: UnsafeMutablePointer<Tag>) {
            unsafe self._base = unsafe pointer
        }

        @inlinable
        public var rawAddress: Memory.Address.Mutable {
            unsafe Memory.Address.Mutable(_base)
        }

        @inlinable
        public func deinitialize(count: Int) -> Memory.Address.Mutable {
            let raw = unsafe _base.deinitialize(count: count)
            return unsafe Memory.Address.Mutable(raw)
        }

        @inlinable
        public func initialize(from source: Pointer<Tag>.Mutable, count: Int) {
            unsafe _base.initialize(from: source.base, count: count)
        }

        @inlinable
        public func initialize(from source: Pointer<Tag>, count: Int) {
            unsafe _base.initialize(from: source.base, count: count)
        }
    }
}

// --- Pointer (immutable) extensions that reference Pointer<Tag>.Mutable ---
extension Tagged where RawValue == Memory.Address, Tag: Copyable {
    @inlinable
    public func copy(to destination: Pointer<Tag>.Mutable, count: Int) {
        unsafe destination.base.initialize(from: self.base, count: count)
    }
}

#endif
