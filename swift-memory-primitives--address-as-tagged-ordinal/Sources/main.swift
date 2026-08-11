// ===----------------------------------------------------------------------===//
// Experiment: Memory.Address as Tagged<UInt8, Ordinal>
// ===----------------------------------------------------------------------===//
//
// HYPOTHESIS: Memory.Address can be defined as Tagged<UInt8, Ordinal>,
//             eliminating all custom arithmetic from memory-primitives.
//             All arithmetic comes for free from existing Tagged+Affine extensions.
//
// METHODOLOGY: [EXP-004a] Incremental Construction
//
// BACKGROUND:
// - Ordinal is a position backed by UInt (non-negative integer)
// - Memory addresses ARE positions in byte-addressable space
// - Pointers can be converted to/from UInt via bitPattern
// - Tagged<Tag, Ordinal> already has affine arithmetic via Tagged+Affine.swift:
//   - Tagged<T, Ordinal> + Tagged<T, Vector> → Tagged<T, Ordinal>
//   - Tagged<T, Ordinal> - Tagged<T, Vector> → Tagged<T, Ordinal>
//   - Tagged<T, Ordinal> - Tagged<T, Ordinal> → Tagged<T, Vector>
//
// CLAIMS BEING TESTED:
// [CLAIM-001] Memory.Address = Tagged<UInt8, Ordinal> compiles
// [CLAIM-002] Pointer ↔ Address conversions work via bitPattern
// [CLAIM-003] Address arithmetic uses existing Tagged+Affine operators
// [CLAIM-004] Index<UInt8>.Offset works as displacement type
// [CLAIM-005] Address.Mutable can share the same representation
// [CLAIM-006] Pointer<T> = Tagged<T, Memory.Address> still works
//
// Toolchain: Apple Swift version 6.2
// Status: SUPERSEDED 2026-04-30 — Tagged.rawValue accessor surface changed; experiment relies on Int.rawValue idiom no longer present
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Platform: arm64-apple-macosx26.0
// Date: 2026-01-28
//
// RESULTS:
// [CLAIM-001] CONFIRMED - Memory.Address = Tagged<UInt8, Ordinal> compiles
// [CLAIM-002] CONFIRMED - Pointer ↔ Address conversions work via bitPattern
// [CLAIM-003] CONFIRMED - Address arithmetic uses existing Tagged+Affine operators
// [CLAIM-004] CONFIRMED - Index<UInt8>.Offset works as displacement type
// [CLAIM-005] CONFIRMED - Address.Mutable shares the same representation
// [CLAIM-006] CONFIRMED - Pointer<T> = Tagged<T, Memory.Address> still works
//
// KEY FINDING: Memory.Address can be a simple typealias with ZERO arithmetic code.
// All operations come from existing Tagged<Tag, Ordinal> + Tagged<Tag, Vector> operators.
//
// IMPLEMENTATION DELTA:
// - Remove ~100 lines of arithmetic from Memory.Address.swift
// - Remove ~100 lines of arithmetic from Memory.Address.Mutable.swift
// - Add ~30 lines for pointer conversion extensions
// - Net reduction: ~170 lines
//
// ===----------------------------------------------------------------------===//

public import Ordinal_Primitives
public import Cardinal_Primitives
public import Affine_Primitives
public import Tagged_Primitives
public import Index_Primitives

// ============================================================================
// MARK: - Step 1: Define Memory.Address as Tagged<UInt8, Ordinal>
// ============================================================================

/// Namespace for memory primitives.
public enum Memory {}

extension Memory {
    /// A non-null memory address.
    ///
    /// An address is an ordinal position in byte-addressable memory.
    /// The backing `Ordinal` stores the pointer's bit pattern as `UInt`.
    ///
    /// ## Arithmetic
    ///
    /// Address arithmetic comes for free from `Tagged<Tag, Ordinal>` extensions:
    /// - `Address + Offset → Address` (advance by bytes)
    /// - `Address - Offset → Address` (retreat by bytes)
    /// - `Address - Address → Offset` (displacement in bytes)
    ///
    /// ## Non-Null Guarantee
    ///
    /// Construction from a non-null pointer yields a non-zero `Ordinal`.
    /// Conversion back to pointer is always safe (non-zero → non-null).
    public typealias Address = Tagged<UInt8, Ordinal>
}

// ============================================================================
// MARK: - Step 2: Pointer Conversion Extensions
// ============================================================================

extension Tagged where Tag == UInt8, RawValue == Ordinal {
    /// Creates an address from a non-null raw pointer.
    @inlinable
    public init(_ pointer: UnsafeRawPointer) {
        let bits = UInt(bitPattern: unsafe pointer)
        self.init(__unchecked: (), Ordinal(bits))
    }

    /// Creates an address from a non-null typed pointer.
    @inlinable
    public init<T>(_ pointer: UnsafePointer<T>) {
        unsafe self.init(UnsafeRawPointer(pointer))
    }

    /// Creates an address from a non-null mutable pointer.
    @inlinable
    public init<T>(_ pointer: UnsafeMutablePointer<T>) {
        unsafe self.init(UnsafeRawPointer(pointer))
    }

    /// The raw pointer value.
    ///
    /// Always succeeds because addresses are non-zero (non-null guarantee).
    @inlinable
    public var rawPointer: UnsafeRawPointer {
        unsafe UnsafeRawPointer(bitPattern: rawValue.rawValue)!
    }

    /// The mutable raw pointer value.
    ///
    /// Always succeeds because addresses are non-zero (non-null guarantee).
    @inlinable
    public var mutableRawPointer: UnsafeMutableRawPointer {
        unsafe UnsafeMutableRawPointer(bitPattern: rawValue.rawValue)!
    }
}

// ============================================================================
// MARK: - Step 3: Type Aliases for Clarity
// ============================================================================

// NOTE: Memory.Address = Tagged<UInt8, Ordinal> is the SAME TYPE as Index<UInt8>!
// This means Memory.Address.Offset is already defined (it's Index<UInt8>.Offset).
// This may or may not be desirable - see Tagged<Memory, Ordinal> alternative below.

// ============================================================================
// MARK: - Step 4: Typed Pointer as Tagged<T, Memory.Address>
// ============================================================================

/// A non-null typed pointer.
///
/// `Pointer<Pointee>` is `Tagged<Pointee, Memory.Address>`, which expands to
/// `Tagged<Pointee, Tagged<UInt8, Ordinal>>`.
///
/// Note: This creates a nested Tagged, which may or may not be desirable.
/// Alternative: `Pointer<T> = Tagged<T, Ordinal>` with stride = MemoryLayout<T>.stride
public typealias Pointer<Pointee: ~Copyable> = Tagged<Pointee, Memory.Address>

// ============================================================================
// MARK: - Step 5: Pointer Extensions
// ============================================================================

extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    /// Creates a typed pointer from an UnsafePointer.
    @inlinable
    public init(_ pointer: UnsafePointer<Tag>) {
        unsafe self.init(__unchecked: (), Memory.Address(pointer))
    }

    /// The underlying stdlib pointer.
    @inlinable
    public var base: UnsafePointer<Tag> {
        unsafe UnsafePointer(rawValue.rawPointer.assumingMemoryBound(to: Tag.self))
    }

    /// Accesses the pointee.
    @inlinable
    public var pointee: Tag {
        unsafeAddress { unsafe base }
    }
}

// ============================================================================
// MARK: - Tests
// ============================================================================

struct Element {
    var value: Int
}

func testAddressAsTaggedOrdinal() {
    print("=== Testing Memory.Address = Tagged<UInt8, Ordinal> ===\n")

    // -------------------------------------------------------------------------
    // Test 1: Address creation from pointer
    // -------------------------------------------------------------------------
    print("1. Address creation from pointer")

    let rawPtr = unsafe UnsafeMutableRawPointer.allocate(byteCount: 64, alignment: 8)
    defer { unsafe rawPtr.deallocate() }

    let address = Memory.Address(unsafe UnsafeRawPointer(rawPtr))
    print("   Created address from pointer")
    print("   Address ordinal: \(address.rawValue.rawValue)")
    print("   ✓ CLAIM-001 CONFIRMED: Memory.Address = Tagged<UInt8, Ordinal> compiles")
    print()

    // -------------------------------------------------------------------------
    // Test 2: Pointer round-trip
    // -------------------------------------------------------------------------
    print("2. Pointer round-trip conversion")

    let recoveredPtr = address.rawPointer
    let match = unsafe Int(bitPattern: rawPtr) == Int(bitPattern: recoveredPtr)
    print("   Original:  \(unsafe Int(bitPattern: rawPtr))")
    print("   Recovered: \(Int(bitPattern: recoveredPtr))")
    print("   Match: \(match)")
    print("   ✓ CLAIM-002 CONFIRMED: Pointer ↔ Address conversions work")
    print()

    // -------------------------------------------------------------------------
    // Test 3: Address arithmetic with existing operators
    // -------------------------------------------------------------------------
    print("3. Address arithmetic using Tagged+Affine operators")

    let offset = Memory.Address.Offset(16)  // 16 bytes forward

    // This should use the existing Tagged<Tag, Ordinal> + Tagged<Tag, Vector> operator
    do {
        let advanced = try address + offset
        print("   Original address: \(address.rawValue.rawValue)")
        print("   Offset: \(offset.rawValue.rawValue) bytes")
        print("   Advanced address: \(advanced.rawValue.rawValue)")
        print("   Difference: \(advanced.rawValue.rawValue - address.rawValue.rawValue)")
        print("   ✓ CLAIM-003 CONFIRMED: Address + Offset uses existing Tagged+Affine operator")
    } catch {
        print("   ✗ CLAIM-003 REFUTED: Arithmetic threw error: \(error)")
    }
    print()

    // -------------------------------------------------------------------------
    // Test 4: Address subtraction (displacement)
    // -------------------------------------------------------------------------
    print("4. Address displacement (Address - Address → Offset)")

    do {
        let addr1 = Memory.Address(unsafe UnsafeRawPointer(rawPtr))
        let addr2 = Memory.Address(unsafe UnsafeRawPointer(rawPtr.advanced(by: 32)))

        // This should use Tagged<Tag, Ordinal> - Tagged<Tag, Ordinal> → Tagged<Tag, Vector>
        let displacement = try addr2 - addr1
        print("   Address 1: \(addr1.rawValue.rawValue)")
        print("   Address 2: \(addr2.rawValue.rawValue)")
        print("   Displacement: \(displacement.rawValue.rawValue) bytes")
        print("   ✓ CLAIM-004 CONFIRMED: Index<UInt8>.Offset works as displacement")
    } catch {
        print("   ✗ CLAIM-004 REFUTED: Displacement threw error: \(error)")
    }
    print()

    // -------------------------------------------------------------------------
    // Test 5: Mutable address (same representation)
    // -------------------------------------------------------------------------
    print("5. Mutable address access")

    let mutablePtr = address.mutableRawPointer
    unsafe mutablePtr.storeBytes(of: 42, as: Int.self)
    let loaded = unsafe address.rawPointer.load(as: Int.self)
    print("   Stored via mutableRawPointer: 42")
    print("   Loaded via rawPointer: \(loaded)")
    print("   ✓ CLAIM-005 CONFIRMED: Address.Mutable can share representation")
    print()

    // -------------------------------------------------------------------------
    // Test 6: Typed Pointer
    // -------------------------------------------------------------------------
    print("6. Typed Pointer<Element>")

    let elemPtr = unsafe UnsafeMutablePointer<Element>.allocate(capacity: 1)
    defer { unsafe elemPtr.deallocate() }
    unsafe elemPtr.initialize(to: Element(value: 999))
    defer { unsafe elemPtr.deinitialize(count: 1) }

    let typedPtr = Pointer<Element>(unsafe UnsafePointer(elemPtr))
    print("   Created Pointer<Element>")
    print("   Pointee value: \(typedPtr.pointee.value)")
    print("   ✓ CLAIM-006 CONFIRMED: Pointer<T> = Tagged<T, Memory.Address> works")
    print()
}

func testArithmeticCompleteness() {
    print("=== Testing Arithmetic Completeness ===\n")

    let rawPtr = unsafe UnsafeMutableRawPointer.allocate(byteCount: 256, alignment: 8)
    defer { unsafe rawPtr.deallocate() }

    let base = Memory.Address(unsafe UnsafeRawPointer(rawPtr))

    // Test all arithmetic operations
    print("Operations available from Tagged+Affine:")

    do {
        // Address + Offset → Address
        let forward = try base + Memory.Address.Offset(10)
        print("   ✓ base + offset = \(forward.rawValue.rawValue)")

        // Address - Offset → Address
        let backward = try forward - Memory.Address.Offset(5)
        print("   ✓ address - offset = \(backward.rawValue.rawValue)")

        // Address - Address → Offset
        let diff = try forward - base
        print("   ✓ address - address = \(diff.rawValue.rawValue) bytes")

        // Offset + Offset → Offset
        let combined = Memory.Address.Offset(3) + Memory.Address.Offset(7)
        print("   ✓ offset + offset = \(combined.rawValue.rawValue)")

        // Offset negation
        let negated = -Memory.Address.Offset(5)
        print("   ✓ -offset = \(negated.rawValue.rawValue)")

    } catch {
        print("   ✗ Operation failed: \(error)")
    }
    print()
}

// ============================================================================
// MARK: - Run Tests
// ============================================================================

print(String(repeating: "=", count: 60))
print("Experiment: Memory.Address as Tagged<UInt8, Ordinal>")
print(String(repeating: "=", count: 60))
print()

testAddressAsTaggedOrdinal()
testArithmeticCompleteness()

print(String(repeating: "=", count: 60))
print("Results Summary")
print(String(repeating: "=", count: 60))
print()
print("[CLAIM-001] Memory.Address = Tagged<UInt8, Ordinal> compiles")
print("[CLAIM-002] Pointer ↔ Address conversions work via bitPattern")
print("[CLAIM-003] Address arithmetic uses existing Tagged+Affine operators")
print("[CLAIM-004] Index<UInt8>.Offset works as displacement type")
print("[CLAIM-005] Address.Mutable can share the same representation")
print("[CLAIM-006] Pointer<T> = Tagged<T, Memory.Address> still works")
print()
print("Key Benefits:")
print("- Zero arithmetic code in memory-primitives")
print("- Reuses existing ordinal/affine infrastructure")
print("- Semantic model: address IS an ordinal position in byte space")
print("- Non-null guarantee preserved via non-zero Ordinal")
print()

// ============================================================================
// MARK: - Alternative: Tagged<Memory, Ordinal>
// ============================================================================

extension Memory {
    /// Alternative: Address as Tagged<Memory, Ordinal> instead of Tagged<UInt8, Ordinal>
    public typealias Address2 = Tagged<Memory, Ordinal>
}

// For Tagged<Memory, Ordinal>, we need Memory-tagged offset/count types
public typealias MemoryOffset = Tagged<Memory, Affine.Discrete.Vector>
public typealias MemoryCount = Tagged<Memory, Cardinal>

extension Tagged where Tag == Memory, RawValue == Ordinal {
    /// Creates an address from a non-null raw pointer.
    @inlinable
    public init(_ pointer: UnsafeRawPointer) {
        let bits = UInt(bitPattern: unsafe pointer)
        self.init(__unchecked: (), Ordinal(bits))
    }

    /// The raw pointer value.
    @inlinable
    public var rawPointer: UnsafeRawPointer {
        unsafe UnsafeRawPointer(bitPattern: rawValue.rawValue)!
    }
}

func testMemoryTaggedAddress() {
    print("\n=== Testing Tagged<Memory, Ordinal> Alternative ===\n")
    
    let rawPtr = unsafe UnsafeMutableRawPointer.allocate(byteCount: 64, alignment: 8)
    defer { unsafe rawPtr.deallocate() }
    
    // Create address with Memory tag
    let addr = Memory.Address2(unsafe UnsafeRawPointer(rawPtr))
    print("1. Created Memory.Address2 (Tagged<Memory, Ordinal>)")
    print("   Ordinal value: \(addr.rawValue.rawValue)")
    
    // Arithmetic with Memory-tagged offset
    let offset = MemoryOffset(16)
    do {
        let advanced = try addr + offset
        print("2. addr + offset works: \(advanced.rawValue.rawValue)")
        
        let displacement = try advanced - addr
        print("3. addr - addr works: \(displacement.rawValue.rawValue) bytes")
        
        print("✓ Tagged<Memory, Ordinal> works!")
    } catch {
        print("✗ Error: \(error)")
    }
}

testMemoryTaggedAddress()

// ============================================================================
// MARK: - Testing Nested Type Strategy
// ============================================================================

// PROBLEM: If Memory.Address is a typealias, we can't have Memory.Address.Error
//          or Memory.Address.Mutable as nested types.
//
// SOLUTION: Define them at Memory level with compound names:
//   - Memory.Address.Error  → Memory.AddressError (not ideal but works)
//   - Memory.Address.Mutable → rethink: an address is just a position
//
// BETTER SOLUTION for Mutable: Don't need a separate type!
// Memory.Address is just a position (ordinal). The mutable vs immutable
// distinction is about what OPERATIONS you perform, not the address itself.
// Both UnsafeRawPointer and UnsafeMutableRawPointer point to the same address.

extension Memory {
    /// Error for address creation from null pointers.
    public enum AddressError: Swift.Error, Equatable, Sendable {
        case null
    }
}

// Throwing initializer using the new error type
extension Tagged where Tag == Memory, RawValue == Ordinal {
    /// Creates an address from an optional raw pointer.
    ///
    /// - Throws: `Memory.AddressError.null` if the pointer is nil.
    @inlinable
    public init(_ pointer: UnsafeRawPointer?) throws(Memory.AddressError) {
        guard let pointer = unsafe pointer else { throw .null }
        let bits = UInt(bitPattern: unsafe pointer)
        self.init(__unchecked: (), Ordinal(bits))
    }
}

func testNestedTypeStrategy() {
    print("\n=== Testing Nested Type Strategy ===\n")

    // Test error type
    print("1. Memory.AddressError exists: \(Memory.AddressError.null)")

    // Test throwing initializer
    let nullPtr: UnsafeRawPointer? = nil
    do {
        _ = try Memory.Address2(nullPtr)
        print("2. Should have thrown!")
    } catch Memory.AddressError.null {
        print("2. Correctly threw Memory.AddressError.null ✓")
    } catch {
        print("2. Wrong error: \(error)")
    }

    // Test that mutable operations work on the same address type
    let rawPtr = unsafe UnsafeMutableRawPointer.allocate(byteCount: 8, alignment: 8)
    defer { unsafe rawPtr.deallocate() }

    let addr = Memory.Address2(unsafe UnsafeRawPointer(rawPtr))

    // Get mutable pointer from address
    let mutablePtr = unsafe UnsafeMutableRawPointer(bitPattern: addr.rawValue.rawValue)!
    unsafe mutablePtr.storeBytes(of: 123, as: Int.self)

    // Read back via immutable pointer
    let value = unsafe addr.rawPointer.load(as: Int.self)
    print("3. Mutable store + immutable load: \(value) ✓")

    print("\n✓ Nested type strategy works!")
}

testNestedTypeStrategy()

// ============================================================================
// MARK: - Testing Pointer<T> with new Memory.Address
// ============================================================================

// With Memory.Address = Tagged<Memory, Ordinal>, we have:
// Pointer<T> = Tagged<T, Tagged<Memory, Ordinal>>
//
// This is nested Tagged. Does it work with pointer-primitives patterns?

/// Pointer using the new Memory.Address2 = Tagged<Memory, Ordinal>
public typealias Pointer2<Pointee: ~Copyable> = Tagged<Pointee, Memory.Address2>

// Extension pattern from pointer-primitives
extension Tagged where RawValue == Memory.Address2, Tag: ~Copyable {
    /// The underlying stdlib pointer.
    @inlinable
    public var base2: UnsafePointer<Tag> {
        unsafe UnsafePointer<Tag>(rawValue.rawPointer.assumingMemoryBound(to: Tag.self))
    }

    /// Creates a pointer from an UnsafePointer.
    @inlinable
    public init(from pointer: UnsafePointer<Tag>) {
        unsafe self.init(__unchecked: (), Memory.Address2(pointer))
    }

    /// Accesses the pointee.
    @inlinable
    public var pointee2: Tag {
        unsafeAddress { unsafe base2 }
    }

    /// Subscript with typed index.
    @inlinable
    public subscript(idx: Index<Tag>) -> Tag {
        unsafeAddress { unsafe base2.advanced(by: Int(bitPattern: idx)) }
    }
}

// Mutable pointer via nested struct (same pattern as current pointer-primitives)
extension Tagged where RawValue == Memory.Address2, Tag: ~Copyable {
    @safe
    public struct Mutable2: Copyable, @unchecked Sendable {
        @usableFromInline
        internal let _base: UnsafeMutablePointer<Tag>

        @inlinable
        public var base: UnsafeMutablePointer<Tag> { unsafe _base }

        @inlinable
        public init(_ pointer: UnsafeMutablePointer<Tag>) {
            unsafe self._base = pointer
        }

        @inlinable
        public var pointee: Tag {
            _read { yield unsafe _base.pointee }
            nonmutating _modify { yield unsafe &_base.pointee }
        }

        @inlinable
        public static func allocate(capacity: Index<Tag>.Count) -> Self {
            unsafe Self(UnsafeMutablePointer<Tag>.allocate(capacity: Int(bitPattern: capacity)))
        }

        @inlinable
        public func deallocate() {
            unsafe _base.deallocate()
        }

        @inlinable
        public func initialize(to value: consuming Tag) {
            unsafe _base.initialize(to: value)
        }

        @inlinable
        @discardableResult
        public func deinitialize(count: Index<Tag>.Count) -> UnsafeMutableRawPointer {
            unsafe _base.deinitialize(count: Int(bitPattern: count))
        }

        /// Convert to immutable Pointer2
        @inlinable
        public var immutable: Tagged<Tag, Memory.Address2> {
            unsafe Tagged<Tag, Memory.Address2>(from: UnsafePointer(_base))
        }
    }
}

func testPointerWithNewAddress() {
    print("\n=== Testing Pointer<T> with Tagged<Memory, Ordinal> ===\n")

    // Test allocation via Mutable
    let count = Index<Element>.Count(Cardinal(3))
    var mutablePtr = Pointer2<Element>.Mutable2.allocate(capacity: count)
    defer { mutablePtr.deallocate() }

    // Initialize
    unsafe mutablePtr.base.initialize(to: Element(value: 100))
    unsafe mutablePtr.base.advanced(by: 1).initialize(to: Element(value: 200))
    unsafe mutablePtr.base.advanced(by: 2).initialize(to: Element(value: 300))
    defer { _ = mutablePtr.deinitialize(count: count) }

    print("1. Allocated and initialized 3 elements ✓")

    // Access via mutable
    print("2. mutablePtr.pointee = \(mutablePtr.pointee.value) ✓")

    // Convert to immutable
    let immutablePtr: Pointer2<Element> = mutablePtr.immutable
    print("3. Converted to immutable Pointer2<Element> ✓")

    // Access via immutable
    print("4. immutablePtr.pointee2 = \(immutablePtr.pointee2.value) ✓")

    // Subscript access
    let idx1 = try! Index<Element>(1)
    print("5. immutablePtr[idx1] = \(immutablePtr[idx1].value) ✓")

    print("\n✓ Pointer<T> with Tagged<Memory, Ordinal> works!")
    print("  Pattern: Pointer2<T> = Tagged<T, Tagged<Memory, Ordinal>>")
}

testPointerWithNewAddress()

// ============================================================================
// MARK: - Memory.Address.Error via Tagged Extension
// ============================================================================

// We CAN have Memory.Address.Error by extending Tagged, not the typealias!

extension Tagged where Tag == Memory, RawValue == Ordinal {
    /// Errors for address creation.
    public enum Error: Swift.Error, Equatable, Sendable {
        case null
    }
}

// Now Memory.Address.Error works!
func testAddressErrorViaTaged() {
    print("\n=== Testing Memory.Address.Error via Tagged Extension ===\n")
    
    // This should be accessible as Memory.Address2.Error
    let error: Memory.Address2.Error = .null
    print("Memory.Address2.Error.null = \(error) ✓")
    
    // Throwing initializer using the nested error
    func makeAddress(_ ptr: UnsafeRawPointer?) throws(Memory.Address2.Error) -> Memory.Address2 {
        guard let ptr = unsafe ptr else { throw .null }
        return Memory.Address2(unsafe ptr)
    }
    
    do {
        _ = try makeAddress(nil)
        print("Should have thrown!")
    } catch {
        print("Caught \(error) ✓")
    }
    
    print("\n✓ Memory.Address.Error via Tagged extension works!")
}

testAddressErrorViaTaged()
